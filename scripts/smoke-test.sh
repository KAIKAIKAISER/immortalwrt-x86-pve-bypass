#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="$(find "$root_dir/openwrt/bin/targets/x86/64" -maxdepth 1 -type f -name '*combined.qcow2' | head -n 1)"
log_file="$root_dir/qemu-smoke.log"

if [[ -z "$image" ]]; then
  echo 'Legacy QCOW2 image not found for smoke test' >&2
  exit 1
fi

set +e
timeout 120s qemu-system-x86_64 \
  -machine accel=tcg \
  -m 512 \
  -smp 2 \
  -nographic \
  -no-reboot \
  -drive "file=$image,format=qcow2,if=virtio" \
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
