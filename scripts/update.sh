#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XRAY_MK="${ROOT_DIR}/packages/aios-xray/Makefile"
V2RAY_MK="${ROOT_DIR}/packages/aios-v2ray/Makefile"
GEODATA_MK="${ROOT_DIR}/packages/aios-geodata/Makefile"

CURL_OPTS=(--connect-timeout 15 --max-time 60 --retry 3)
TMP_FILES=()

cleanup() {
	local f
	for f in "${TMP_FILES[@]:-}"; do
		if [ -n "$f" ]; then
			rm -f "$f"
		fi
	done
	return 0
}
trap cleanup EXIT INT TERM

usage() {
	cat <<'EOF'
Usage:
  scripts/update.sh all
  scripts/update.sh xray [version]     # e.g. 26.11.9 (omit to fetch latest release)
  scripts/update.sh v2ray [version]    # e.g. 5.56.0  (omit to fetch latest release)
  scripts/update.sh geodata [tag]      # Loyalsoldier/v2ray-rules-dat release tag
EOF
}

die() {
	echo "ERROR: $*" >&2
	exit 1
}

validate_sha256() {
	local sha="$1" label="$2"
	if ! printf '%s\n' "$sha" | grep -qE '^[0-9a-fA-F]{64}$'; then
		die "Invalid SHA256 for ${label}: '${sha}'"
	fi
}

normalize_ver14() {
	local raw="$1"
	if ! printf '%s\n' "$raw" | grep -qE '^[0-9]{12,14}$'; then
		die "Invalid GeoData release tag (expected 12-14 digits): '${raw}'"
	fi
	while [ "${#raw}" -lt 14 ]; do
		raw="${raw}0"
	done
	printf '%s\n' "${raw:0:14}"
}

sha256_stdin() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum | awk '{print $1}'
	else
		shasum -a 256 | awk '{print $1}'
	fi
}

get_var() {
	local file="$1" key="$2"
	awk -v k="$key" 'index($0, k ":=") == 1 { print substr($0, length(k) + 3); exit }' "$file"
}

# Returns 0 if version $1 is strictly less than version $2.
# Supports dotted numeric versions, optional -prerelease suffixes, and 14-digit integers.
version_lt() {
	awk -v a="$1" -v b="$2" '
		function cmp_num(x, y) {
			sub(/^0+/, "", x); if (x == "") x = "0"
			sub(/^0+/, "", y); if (y == "") y = "0"
			if (length(x) != length(y)) return (length(x) < length(y)) ? -1 : 1
			return (x < y) ? -1 : (x > y ? 1 : 0)
		}
		function split_alnum(s, arr,    n, p, tok) {
			n = 0
			while (length(s) > 0) {
				if (match(s, /^[0-9]+/)) {
					tok = substr(s, 1, RLENGTH)
					s = substr(s, RLENGTH + 1)
				} else if (match(s, /^[^0-9]+/)) {
					tok = substr(s, 1, RLENGTH)
					s = substr(s, RLENGTH + 1)
				} else {
					break
				}
				arr[++n] = tok
			}
			return n
		}
		function cmp_ident(x, y,    n1, n2, m, i, t1, t2, p1, p2, r) {
			if (x ~ /^[0-9]+$/ && y ~ /^[0-9]+$/) return cmp_num(x, y)
			n1 = split_alnum(x, t1)
			n2 = split_alnum(y, t2)
			m = (n1 < n2) ? n1 : n2
			for (i = 1; i <= m; i++) {
				p1 = t1[i]; p2 = t2[i]
				if (p1 ~ /^[0-9]+$/ && p2 ~ /^[0-9]+$/) {
					r = cmp_num(p1, p2)
				} else {
					r = (p1 < p2) ? -1 : (p1 > p2 ? 1 : 0)
				}
				if (r != 0) return r
			}
			return (n1 < n2) ? -1 : (n1 > n2 ? 1 : 0)
		}
		function cmp_core(s1, s2,    n1, n2, n, i, a1, a2, r) {
			n1 = split(s1, a1, ".")
			n2 = split(s2, a2, ".")
			n = (n1 > n2) ? n1 : n2
			for (i = 1; i <= n; i++) {
				r = cmp_ident((i <= n1 ? a1[i] : "0"), (i <= n2 ? a2[i] : "0"))
				if (r != 0) return r
			}
			return 0
		}
		function cmp_pre(s1, s2,    n1, n2, m, i, a1, a2, r) {
			n1 = split(s1, a1, ".")
			n2 = split(s2, a2, ".")
			m = (n1 < n2) ? n1 : n2
			for (i = 1; i <= m; i++) {
				r = cmp_ident(a1[i], a2[i])
				if (r != 0) return r
			}
			return (n1 < n2) ? -1 : (n1 > n2 ? 1 : 0)
		}
		BEGIN {
			idx_a = index(a, "-")
			core_a = (idx_a > 0) ? substr(a, 1, idx_a - 1) : a
			pre_a  = (idx_a > 0) ? substr(a, idx_a + 1) : ""

			idx_b = index(b, "-")
			core_b = (idx_b > 0) ? substr(b, 1, idx_b - 1) : b
			pre_b  = (idx_b > 0) ? substr(b, idx_b + 1) : ""

			r = cmp_core(core_a, core_b)
			if (r != 0) exit (r < 0 ? 0 : 1)

			if (pre_a == "" && pre_b == "") exit 1
			if (pre_a != "" && pre_b == "") exit 0
			if (pre_a == "" && pre_b != "") exit 1

			r = cmp_pre(pre_a, pre_b)
			exit (r < 0 ? 0 : 1)
		}
	'
}

latest_tag() {
	local repo="$1" tag
	tag="$(curl -fsSLI "${CURL_OPTS[@]}" -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest" \
		| awk -F'/' '{print $NF}')"
	if [ -z "$tag" ] || [ "$tag" = "releases" ] || [ "$tag" = "latest" ]; then
		die "Failed to resolve latest release tag for ${repo} (got '${tag}')"
	fi
	printf '%s\n' "$tag"
}

latest_tag_including_prerelease() {
	local repo="$1" json tag
	local -a curl_args=(-fsSL "${CURL_OPTS[@]}" -H "Accept: application/vnd.github+json")
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
	fi
	json="$(curl "${curl_args[@]}" "https://api.github.com/repos/${repo}/releases?per_page=10")"
	if command -v jq >/dev/null 2>&1; then
		tag="$(printf '%s' "$json" | jq -r '[.[] | select(.draft == false and (.tag_name | length > 0))][0].tag_name // empty')"
	elif command -v python3 >/dev/null 2>&1; then
		tag="$(printf '%s' "$json" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next((r["tag_name"] for r in data if not r.get("draft") and r.get("tag_name")), ""))')"
	else
		die "jq or python3 is required to parse GitHub releases API for ${repo}"
	fi
	if [ -z "$tag" ]; then
		die "Failed to resolve latest release tag (including prereleases) for ${repo}"
	fi
	printf '%s\n' "$tag"
}

replace_var() {
	local file="$1" key="$2" val="$3"
	local dir tmp
	dir="$(dirname "$file")"
	tmp="$(mktemp "${dir}/.tmp.XXXXXX")"
	TMP_FILES+=("$tmp")
	if ! awk -v k="$key" -v v="$val" '
		BEGIN { found = 0 }
		index($0, k ":=") == 1 { print k ":=" v; found++; next }
		{ print }
		END { if (found == 0) exit 2 }
	' "$file" > "$tmp"; then
		die "Key '${key}:=' not found in ${file}"
	fi
	mv -f "$tmp" "$file"
}

update_xray() {
	local ver="${1:-}" explicit=1
	if [ -z "$ver" ]; then
		explicit=0
		ver="$(latest_tag XTLS/Xray-core)"
	fi
	ver="${ver#v}"
	if ! printf '%s\n' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$'; then
		die "Invalid Xray version: '${ver}'"
	fi

	local cur_ver
	cur_ver="$(get_var "$XRAY_MK" "PKG_VERSION")"
	if [ "$explicit" -eq 0 ] && [ -n "$cur_ver" ] && version_lt "$ver" "$cur_ver"; then
		echo "[aios-xray] Upstream ${ver} is older than current ${cur_ver}; skipping downgrade."
		return 0
	fi

	echo "[aios-xray] Fetching SHA256 for v${ver}..."
	local sha
	sha="$(curl -fsSL "${CURL_OPTS[@]}" "https://codeload.github.com/XTLS/Xray-core/tar.gz/v${ver}" | sha256_stdin)"
	validate_sha256 "$sha" "aios-xray ${ver}"

	local tmp_mk
	tmp_mk="$(mktemp "$(dirname "$XRAY_MK")/.xray.XXXXXX")"
	TMP_FILES+=("$tmp_mk")
	cp "$XRAY_MK" "$tmp_mk"
	replace_var "$tmp_mk" "PKG_VERSION" "$ver"
	if [ "$ver" != "$cur_ver" ]; then
		replace_var "$tmp_mk" "PKG_RELEASE" "1"
	fi
	replace_var "$tmp_mk" "PKG_HASH" "$sha"
	chmod 0644 "$tmp_mk"
	mv -f "$tmp_mk" "$XRAY_MK"
	echo "[aios-xray] Updated to ${ver} (${sha})"
}

update_v2ray() {
	local ver="${1:-}" explicit=1
	if [ -z "$ver" ]; then
		explicit=0
		ver="$(latest_tag_including_prerelease v2fly/v2ray-core)"
	fi
	ver="${ver#v}"
	if ! printf '%s\n' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$'; then
		die "Invalid V2Ray version: '${ver}'"
	fi

	local cur_ver
	cur_ver="$(get_var "$V2RAY_MK" "PKG_VERSION")"
	if [ "$explicit" -eq 0 ] && [ -n "$cur_ver" ] && version_lt "$ver" "$cur_ver"; then
		echo "[aios-v2ray] Upstream ${ver} is older than current ${cur_ver}; skipping downgrade."
		return 0
	fi

	echo "[aios-v2ray] Fetching SHA256 for v${ver}..."
	local sha
	sha="$(curl -fsSL "${CURL_OPTS[@]}" "https://codeload.github.com/v2fly/v2ray-core/tar.gz/v${ver}" | sha256_stdin)"
	validate_sha256 "$sha" "aios-v2ray ${ver}"

	local tmp_mk
	tmp_mk="$(mktemp "$(dirname "$V2RAY_MK")/.v2ray.XXXXXX")"
	TMP_FILES+=("$tmp_mk")
	cp "$V2RAY_MK" "$tmp_mk"
	replace_var "$tmp_mk" "PKG_VERSION" "$ver"
	if [ "$ver" != "$cur_ver" ]; then
		replace_var "$tmp_mk" "PKG_RELEASE" "1"
	fi
	replace_var "$tmp_mk" "PKG_HASH" "$sha"
	chmod 0644 "$tmp_mk"
	mv -f "$tmp_mk" "$V2RAY_MK"
	echo "[aios-v2ray] Updated to ${ver} (${sha})"
}

update_geodata() {
	local tag="${1:-}" explicit=1
	if [ -z "$tag" ]; then
		explicit=0
		tag="$(latest_tag Loyalsoldier/v2ray-rules-dat)"
	fi
	local ver14
	ver14="$(normalize_ver14 "$tag")"

	local cur_ver
	cur_ver="$(get_var "$GEODATA_MK" "PKG_VERSION")"
	if [ "$explicit" -eq 0 ] && [ -n "$cur_ver" ] && version_lt "$ver14" "$cur_ver"; then
		echo "[aios-geodata] Upstream ${ver14} (tag=${tag}) is older than current ${cur_ver}; skipping downgrade."
		return 0
	fi

	echo "[aios-geodata] Fetching Loyalsoldier/v2ray-rules-dat SHA256 for ${tag} (PKG_VERSION=${ver14})..."
	local geoip_sha geosite_sha
	geoip_sha="$(curl -fsSL "${CURL_OPTS[@]}" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${tag}/geoip.dat.sha256sum" | awk '{print $1}')"
	geosite_sha="$(curl -fsSL "${CURL_OPTS[@]}" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${tag}/geosite.dat.sha256sum" | awk '{print $1}')"
	validate_sha256 "$geoip_sha" "geoip.dat (${tag})"
	validate_sha256 "$geosite_sha" "geosite.dat (${tag})"

	local tmp_mk
	tmp_mk="$(mktemp "$(dirname "$GEODATA_MK")/.geodata.XXXXXX")"
	TMP_FILES+=("$tmp_mk")
	cp "$GEODATA_MK" "$tmp_mk"
	replace_var "$tmp_mk" "PKG_VERSION" "$ver14"
	if [ "$ver14" != "$cur_ver" ]; then
		replace_var "$tmp_mk" "PKG_RELEASE" "1"
	fi
	replace_var "$tmp_mk" "GEOIP_VER" "$tag"
	replace_var "$tmp_mk" "GEOSITE_VER" "$tag"
	replace_var "$tmp_mk" "GEOIP_HASH" "$geoip_sha"
	replace_var "$tmp_mk" "GEOSITE_HASH" "$geosite_sha"
	chmod 0644 "$tmp_mk"
	mv -f "$tmp_mk" "$GEODATA_MK"
	echo "[aios-geodata] Updated to ${ver14} (tag=${tag}, geoip=${geoip_sha:0:12}..., geosite=${geosite_sha:0:12}...)"
}

cmd="${1:-}"
case "$cmd" in
	all)
		update_xray
		update_v2ray
		update_geodata
		;;
	xray)
		update_xray "${2:-}"
		;;
	v2ray)
		update_v2ray "${2:-}"
		;;
	geodata)
		update_geodata "${2:-}"
		;;
	*)
		usage
		exit 1
		;;
esac
