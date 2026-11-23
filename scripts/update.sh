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

update_geodata() {
	local ver="${1:-}"
	[ -n "$ver" ] || ver="$(latest_tag Loyalsoldier/v2ray-rules-dat)"

	echo "[aios-geodata] Fetching Loyalsoldier/v2ray-rules-dat SHA256 for ${ver}..."
	local geoip_sha geosite_sha
	geoip_sha="$(curl -fsSL "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${ver}/geoip.dat.sha256sum" | awk '{print $1}')"
	geosite_sha="$(curl -fsSL "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${ver}/geosite.dat.sha256sum" | awk '{print $1}')"

	replace_var "$GEODATA_MK" "PKG_VERSION" "$ver"
	replace_var "$GEODATA_MK" "GEOIP_HASH" "$geoip_sha"
	replace_var "$GEODATA_MK" "GEOSITE_HASH" "$geosite_sha"
	echo "[aios-geodata] Updated to ${ver} (geoip=${geoip_sha:0:12}..., geosite=${geosite_sha:0:12}...)"
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
