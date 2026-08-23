#!/usr/bin/env bash
set -euo pipefail

: "${IMMORTALWRT_TAG:?IMMORTALWRT_TAG is required}"
: "${OPENCLASH_TAG:?OPENCLASH_TAG is required}"
: "${OPENCLASH_CORE_SHA:?OPENCLASH_CORE_SHA is required}"

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${BUILD_DIR:-$root_dir/openwrt}"

if [[ -e "$build_dir" ]]; then
  echo "Build directory already exists: $build_dir" >&2
  exit 1
fi

git clone --depth 1 --branch "$IMMORTALWRT_TAG" --single-branch \
  https://github.com/immortalwrt/immortalwrt.git "$build_dir"

pushd "$build_dir" >/dev/null
./scripts/feeds update -a
./scripts/feeds install -a

git clone --depth 1 --branch "$OPENCLASH_TAG" --single-branch \
  https://github.com/vernesong/OpenClash.git "$build_dir/openclash-source"
cp -a "$build_dir/openclash-source/luci-app-openclash" "$build_dir/package/"
rm -rf "$build_dir/openclash-source"

cp "$root_dir/configs/x86_64-pve.config" .config
cp -a "$root_dir/files" .

mkdir -p files/etc/openclash/core
core_archive="$(mktemp)"
core_unpack="$(mktemp -d)"
core_url="https://raw.githubusercontent.com/vernesong/OpenClash/${OPENCLASH_CORE_SHA}/master/meta/clash-linux-amd64-v1.tar.gz"
curl --fail --location --retry 3 --output "$core_archive" "$core_url"
tar -xzf "$core_archive" -C "$core_unpack"
install -m 0755 "$core_unpack/clash" files/etc/openclash/core/clash_meta
files/etc/openclash/core/clash_meta -v
sha256sum "$core_archive" | awk '{print $1}' > "$root_dir/core.sha256"
rm -f "$core_archive"
rm -rf "$core_unpack"

make defconfig
popd >/dev/null
