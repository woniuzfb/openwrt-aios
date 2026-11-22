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
  scripts/update.sh geodata [geoip_tag] [geosite_tag]
EOF
}

sha256_stdin() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum | awk '{print $1}'
	else
		shasum -a 256 | awk '{print $1}'
	fi
}

latest_tag() {
	local repo="$1"
	curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest" \
		| awk -F'/' '{print $NF}'
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
	echo "[aios-xray] Fetching SHA256 for v${ver}..."
	local sha
	sha="$(curl -fsSL "https://codeload.github.com/XTLS/Xray-core/tar.gz/v${ver}" | sha256_stdin)"
	replace_var "$XRAY_MK" "PKG_VERSION" "$ver"
	replace_var "$XRAY_MK" "PKG_HASH" "$sha"
	echo "[aios-xray] Updated to ${ver} (${sha})"
}

update_v2ray() {
	local ver="${1:-}"
	if [ -z "$ver" ]; then
		ver="$(latest_tag v2fly/v2ray-core)"
	fi
	ver="${ver#v}"
	echo "[aios-v2ray] Fetching SHA256 for v${ver}..."
	local sha
	sha="$(curl -fsSL "https://codeload.github.com/v2fly/v2ray-core/tar.gz/v${ver}" | sha256_stdin)"
	replace_var "$V2RAY_MK" "PKG_VERSION" "$ver"
	replace_var "$V2RAY_MK" "PKG_HASH" "$sha"
	echo "[aios-v2ray] Updated to ${ver} (${sha})"
}

normalize_ver14() {
	local v="$1"
	while [ "${#v}" -lt 14 ]; do
		v="${v}0"
	done
	printf '%s' "${v:0:14}"
}

update_geodata() {
	local geoip_ver="${1:-}"
	local geosite_ver="${2:-}"
	[ -n "$geoip_ver" ] || geoip_ver="$(latest_tag v2fly/geoip)"
	[ -n "$geosite_ver" ] || geosite_ver="$(latest_tag v2fly/domain-list-community)"

	echo "[aios-geodata] Fetching SHA256 for geoip=${geoip_ver}, geosite=${geosite_ver}..."
	local geoip_sha geosite_sha geoip_norm geosite_norm pkg_ver
	geoip_sha="$(curl -fsSL "https://github.com/v2fly/geoip/releases/download/${geoip_ver}/geoip.dat.sha256sum" | awk '{print $1}')"
	geosite_sha="$(curl -fsSL "https://github.com/v2fly/domain-list-community/releases/download/${geosite_ver}/dlc.dat.sha256sum" | awk '{print $1}')"
	geoip_norm="$(normalize_ver14 "$geoip_ver")"
	geosite_norm="$(normalize_ver14 "$geosite_ver")"
	if [ "$geoip_norm" \> "$geosite_norm" ]; then
		pkg_ver="$geoip_norm"
	else
		pkg_ver="$geosite_norm"
	fi

	replace_var "$GEODATA_MK" "PKG_VERSION" "$pkg_ver"
	replace_var "$GEODATA_MK" "GEOIP_VER" "$geoip_ver"
	replace_var "$GEODATA_MK" "GEOIP_HASH" "$geoip_sha"
	replace_var "$GEODATA_MK" "GEOSITE_VER" "$geosite_ver"
	replace_var "$GEODATA_MK" "GEOSITE_HASH" "$geosite_sha"
	echo "[aios-geodata] Updated to ${pkg_ver} (geoip=${geoip_ver}, geosite=${geosite_ver})"
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
		update_geodata "${2:-}" "${3:-}"
		;;
	*)
		usage
		exit 1
		;;
esac
