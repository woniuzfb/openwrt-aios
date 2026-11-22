#!/usr/bin/env bash
set -euo pipefail

# Release helper for openwrt-aios
# Usage: ./scripts/release.sh [tag] [--update [all|xray|v2ray|geodata]] [--push]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
	cat <<'USAGE_EOF'
Usage: ./scripts/release.sh [tag] [--update [all|xray|v2ray|geodata]] [--push]

Options:
  [tag]                 Release tag starting with 'v' (default: vYYYY.MM.DD)
  --update [target]     Run scripts/update.sh <target> before tagging (default target: all)
  --push                Push branch and tag to origin to trigger GitHub Actions build & release
USAGE_EOF
}

die() {
	echo "ERROR: $*" >&2
	exit 1
}

TAG=""
DO_UPDATE=0
UPDATE_TARGET="all"
DO_PUSH=0

while [ $# -gt 0 ]; do
	case "$1" in
		--update)
			DO_UPDATE=1
			if [ $# -ge 2 ] && [[ "${2}" != --* ]]; then
				UPDATE_TARGET="$2"
				shift 2
			else
				shift
			fi
			;;
		--push)
			DO_PUSH=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		v*)
			[ -z "$TAG" ] || die "Multiple tags specified: $TAG and $1"
			TAG="$1"
			shift
			;;
		*)
			die "Unknown argument: $1 (tag must start with 'v', e.g. v2026.11.22)"
			;;
	esac
done

[ -n "$TAG" ] || TAG="v$(date +%Y.%m.%d)"
if ! printf '%s\n' "$TAG" | grep -qE '^v[0-9A-Za-z._-]+$'; then
	die "Invalid tag format: ${TAG}"
fi

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
	die "Tag ${TAG} already exists"
fi

if [ -n "$(git status --porcelain)" ]; then
	die "Working tree is not clean. Commit or stash changes before running release.sh"
fi

if [ "$DO_UPDATE" -eq 1 ]; then
	echo "==> 1. Updating upstream package versions (${UPDATE_TARGET})..."
	./scripts/update.sh "$UPDATE_TARGET"
fi

echo "==> 2. Validating scripts, workflows, and package Makefiles..."
bash -n scripts/update.sh scripts/release.sh
ruby -ryaml -e "Dir.glob('.github/workflows/*.yml').each { |f| YAML.load_file(f) }; puts 'YAML_OK'"

for mk in \
	packages/aios-xray/Makefile \
	packages/aios-v2ray/Makefile \
	packages/aios-geodata/Makefile; do
	[ -f "$mk" ] || die "Missing Makefile: $mk"
	grep -qE '^PKG_VERSION:=.+' "$mk" || die "Missing PKG_VERSION in $mk"
	if grep -q 'HASH:=skip' "$mk"; then
		die "HASH:=skip is forbidden in $mk"
	fi
done

if ! git diff --quiet packages/; then
	git add packages/
	git commit -m "chore(release): bump upstream versions for ${TAG}"
fi

XRAY_VER="$(sed -nE 's/^PKG_VERSION:=(.+)$/\1/p' packages/aios-xray/Makefile)"
V2RAY_VER="$(sed -nE 's/^PKG_VERSION:=(.+)$/\1/p' packages/aios-v2ray/Makefile)"
GEO_VER="$(sed -nE 's/^PKG_VERSION:=(.+)$/\1/p' packages/aios-geodata/Makefile)"

git tag -a "$TAG" -m "Release ${TAG} (aios-xray ${XRAY_VER}, aios-v2ray ${V2RAY_VER}, aios-geodata ${GEO_VER})"
BRANCH="$(git branch --show-current)"
echo "==> Created annotated tag ${TAG} on branch ${BRANCH} (xray=${XRAY_VER}, v2ray=${V2RAY_VER}, geodata=${GEO_VER})."

if [ "$DO_PUSH" -eq 1 ]; then
	echo "==> Pushing ${BRANCH} and ${TAG} to origin..."
	git push origin "$BRANCH"
	git push origin "$TAG"
	echo "==> Release ${TAG} pushed. Monitor GitHub Actions for SDK matrix builds and Release assets."
else
	echo "Dry-push mode (tag created locally). Run the following commands to publish:"
	echo "  git push origin ${BRANCH}"
	echo "  git push origin ${TAG}"
fi
