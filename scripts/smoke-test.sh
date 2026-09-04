#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$root_dir/openwrt/bin/targets/x86/64"
log_file="$root_dir/qemu-smoke.log"
temporary_image=""

cleanup() {
  if [[ -n "$temporary_image" ]]; then
    rm -f -- "$temporary_image"
  fi
}
trap cleanup EXIT

# CONFIG_TARGET_IMAGES_GZIP compresses the single raw disk image as *.img.gz.
# QEMU needs an uncompressed copy for the boot smoke test.
image="$(find "$target_dir" -maxdepth 1 -type f \( \
  -name '*combined.img' -o -name '*combined.img.gz' \
\) -print -quit)"

if [[ -z "$image" ]]; then
  echo "No legacy BIOS combined IMG found in $target_dir" >&2
  find "$target_dir" -maxdepth 1 -type f -printf '%f\n' | sort >&2
  exit 1
fi

if [[ "$image" == *.img.gz ]]; then
  temporary_image="$(mktemp --suffix=.img)"
  gzip -dc -- "$image" > "$temporary_image"
  image="$temporary_image"
fi

echo "Using raw IMG image: $image"

set +e
timeout 120s qemu-system-x86_64 \
  -machine accel=tcg \
  -m 512 \
  -smp 2 \
  -nographic \
  -no-reboot \
  -drive "file=$image,format=raw,if=virtio" \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 >"$log_file" 2>&1
qemu_status=$?
set -e

cat "$log_file"

if [[ "$qemu_status" -ne 0 && "$qemu_status" -ne 124 ]]; then
  echo "QEMU exited unexpectedly with status $qemu_status" >&2
  exit 1
fi

grep -Eq 'ImmortalWrt|Please press Enter to activate this console|procd: - init complete -' "$log_file"
