#!/usr/bin/env bash
set -euo pipefail

: "${IMMORTALWRT_TAG:?IMMORTALWRT_TAG is required}"
: "${OPENCLASH_TAG:?OPENCLASH_TAG is required}"
: "${OPENCLASH_CORE_SHA:?OPENCLASH_CORE_SHA is required}"

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$root_dir/openwrt/bin/targets/x86/64"
dist_dir="$root_dir/dist"

mkdir -p "$dist_dir"

find "$target_dir" -maxdepth 1 -type f \
  \( -name '*combined*.img.gz' -o -name '*combined*.qcow2' -o \
     -name '*combined*.qcow2.gz' -o \
     -name '*.manifest' -o -name '*.buildinfo' -o -name 'profiles.json' \) \
  -exec cp -v {} "$dist_dir/" \;

while IFS= read -r -d '' image; do
  zstd -T0 -19 --rm "$image"
done < <(find "$dist_dir" -maxdepth 1 -type f -name '*.qcow2' -print0)

cp "$root_dir/configs/x86_64-pve.config" "$dist_dir/requested.config"
cp "$root_dir/openwrt/.config" "$dist_dir/resolved.config"
cp "$root_dir/openwrt/feeds.conf.default" "$dist_dir/feeds.conf.default"

cat > "$dist_dir/build-metadata.txt" <<EOF
immortalwrt_tag=$IMMORTALWRT_TAG
immortalwrt_commit=$(git -C "$root_dir/openwrt" rev-parse HEAD)
openclash_tag=$OPENCLASH_TAG
openclash_core_commit=$OPENCLASH_CORE_SHA
openclash_core_archive_sha256=$(cat "$root_dir/core.sha256")
github_repository=${GITHUB_REPOSITORY:-local}
github_run_id=${GITHUB_RUN_ID:-local}
build_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

pushd "$dist_dir" >/dev/null
sha256sum -- * > SHA256SUMS
popd >/dev/null
