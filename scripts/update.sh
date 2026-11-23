#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XRAY_MK="${ROOT_DIR}/packages/aios-xray/Makefile"
V2RAY_MK="${ROOT_DIR}/packages/aios-v2ray/Makefile"
GEODATA_MK="${ROOT_DIR}/packages/aios-geodata/Makefile"

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

latest_tag() {
	local repo="$1" tag
	tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest" \
		| awk -F'/' '{print $NF}')"
	if [ -z "$tag" ] || [ "$tag" = "releases" ] || [ "$tag" = "latest" ]; then
		die "Failed to resolve latest release tag for ${repo} (got '${tag}')"
	fi
	printf '%s\n' "$tag"
}

latest_tag_including_prerelease() {
	local repo="$1" json tag
	local -a curl_args=(-fsSL -H "Accept: application/vnd.github+json")
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
	local tmp="${file}.tmp"
	awk -v k="$key" -v v="$val" '
		index($0, k ":=") == 1 { print k ":=" v; next }
		{ print }
	' "$file" > "$tmp"
	mv -f "$tmp" "$file"
}

update_xray() {
	local ver="${1:-}"
	if [ -z "$ver" ]; then
		ver="$(latest_tag XTLS/Xray-core)"
	fi
	ver="${ver#v}"
	if ! printf '%s\n' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$'; then
		die "Invalid Xray version: '${ver}'"
	fi
	echo "[aios-xray] Fetching SHA256 for v${ver}..."
	local sha
	sha="$(curl -fsSL "https://codeload.github.com/XTLS/Xray-core/tar.gz/v${ver}" | sha256_stdin)"
	validate_sha256 "$sha" "aios-xray ${ver}"
	replace_var "$XRAY_MK" "PKG_VERSION" "$ver"
	replace_var "$XRAY_MK" "PKG_HASH" "$sha"
	echo "[aios-xray] Updated to ${ver} (${sha})"
}

update_v2ray() {
	local ver="${1:-}"
	if [ -z "$ver" ]; then
		ver="$(latest_tag_including_prerelease v2fly/v2ray-core)"
	fi
	ver="${ver#v}"
	if ! printf '%s\n' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$'; then
		die "Invalid V2Ray version: '${ver}'"
	fi
	echo "[aios-v2ray] Fetching SHA256 for v${ver}..."
	local sha
	sha="$(curl -fsSL "https://codeload.github.com/v2fly/v2ray-core/tar.gz/v${ver}" | sha256_stdin)"
	validate_sha256 "$sha" "aios-v2ray ${ver}"
	replace_var "$V2RAY_MK" "PKG_VERSION" "$ver"
	replace_var "$V2RAY_MK" "PKG_HASH" "$sha"
	echo "[aios-v2ray] Updated to ${ver} (${sha})"
}

update_geodata() {
	local tag="${1:-}"
	[ -n "$tag" ] || tag="$(latest_tag Loyalsoldier/v2ray-rules-dat)"
	local ver14
	ver14="$(normalize_ver14 "$tag")"

	echo "[aios-geodata] Fetching Loyalsoldier/v2ray-rules-dat SHA256 for ${tag} (PKG_VERSION=${ver14})..."
	local geoip_sha geosite_sha
	geoip_sha="$(curl -fsSL "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${tag}/geoip.dat.sha256sum" | awk '{print $1}')"
	geosite_sha="$(curl -fsSL "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${tag}/geosite.dat.sha256sum" | awk '{print $1}')"
	validate_sha256 "$geoip_sha" "geoip.dat (${tag})"
	validate_sha256 "$geosite_sha" "geosite.dat (${tag})"

	replace_var "$GEODATA_MK" "PKG_VERSION" "$ver14"
	replace_var "$GEODATA_MK" "GEOIP_VER" "$tag"
	replace_var "$GEODATA_MK" "GEOSITE_VER" "$tag"
	replace_var "$GEODATA_MK" "GEOIP_HASH" "$geoip_sha"
	replace_var "$GEODATA_MK" "GEOSITE_HASH" "$geosite_sha"
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
