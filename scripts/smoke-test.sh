#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$root_dir/openwrt/bin/targets/x86/64"
image="$(find "$target_dir" -maxdepth 1 -type f -name '*combined.qcow2' -print -quit)"
firmware_args=()
log_file="$root_dir/qemu-smoke.log"

if [[ -z "$image" ]]; then
  image="$(find "$target_dir" -maxdepth 1 -type f -name '*combined-efi.qcow2' -print -quit)"
  if [[ -n "$image" ]]; then
    for firmware in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
      if [[ -f "$firmware" ]]; then
        firmware_args=(-bios "$firmware")
        break
      fi
    done
  fi
fi

if [[ -z "$image" ]]; then
  echo "No legacy or EFI QCOW2 image found in $target_dir" >&2
  find "$target_dir" -maxdepth 1 -type f -printf '%f\n' | sort >&2
  exit 1
fi

if [[ "$image" == *-combined-efi.qcow2 && "${#firmware_args[@]}" -eq 0 ]]; then
  echo 'EFI QCOW2 image found but no OVMF firmware was installed' >&2
  exit 1
fi

set +e
timeout 120s qemu-system-x86_64 \
  -machine accel=tcg \
  -m 512 \
  -smp 2 \
  -nographic \
  -no-reboot \
  "${firmware_args[@]}" \
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
