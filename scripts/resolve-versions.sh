#!/usr/bin/env bash
set -euo pipefail

series="${IMMORTALWRT_SERIES:-24.10}"
force="${FORCE_BUILD:-false}"

immortalwrt_tag="$({
  git ls-remote --tags --refs https://github.com/immortalwrt/immortalwrt.git "v${series}.*" |
    awk -F/ '{print $3}' |
    grep -E "^v${series//./\\.}\\.[0-9]+$" |
    sort -V
} | tail -n 1)"

if [[ -z "$immortalwrt_tag" ]]; then
  echo "No stable ImmortalWrt tag found for ${series}" >&2
  exit 1
fi

openclash_tag="$(gh api repos/vernesong/OpenClash/releases/latest --jq .tag_name)"
core_sha="$(git ls-remote https://github.com/vernesong/OpenClash.git refs/heads/core | awk '{print $1}')"

if [[ -z "$openclash_tag" || -z "$core_sha" ]]; then
  echo "Failed to resolve OpenClash release/core versions" >&2
  exit 1
fi

base_tag="${immortalwrt_tag}-pve-oc${openclash_tag#v}-core${core_sha:0:7}"
release_tag="$base_tag"
should_build=true

if gh release view "$base_tag" >/dev/null 2>&1; then
  if [[ "$force" == "true" ]]; then
    release_tag="${base_tag}-manual${GITHUB_RUN_NUMBER:-0}"
  else
    should_build=false
  fi
fi

{
  echo "immortalwrt_tag=$immortalwrt_tag"
  echo "openclash_tag=$openclash_tag"
  echo "core_sha=$core_sha"
  echo "release_tag=$release_tag"
  echo "should_build=$should_build"
} >> "${GITHUB_OUTPUT:-build-metadata.env}"

printf 'ImmortalWrt: %s\nOpenClash: %s\nCore: %s\nRelease: %s\nBuild: %s\n' \
  "$immortalwrt_tag" "$openclash_tag" "$core_sha" "$release_tag" "$should_build"
