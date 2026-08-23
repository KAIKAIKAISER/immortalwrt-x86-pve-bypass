#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${BUILD_DIR:-$root_dir/openwrt}"

"$root_dir/scripts/validate-config.sh" "$build_dir/.config"

pushd "$build_dir" >/dev/null
make download -j8 V=s

jobs="${BUILD_JOBS:-$(nproc)}"
if ! make -j"$jobs"; then
  echo 'Parallel build failed; retrying once with a verbose single job.' >&2
  make -j1 V=s
fi
popd >/dev/null
