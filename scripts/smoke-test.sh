#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$root_dir/openwrt/bin/targets/x86/64"
firmware_args=()
log_file="$root_dir/qemu-smoke.log"
temporary_image=""

cleanup() {
  if [[ -n "$temporary_image" ]]; then
    rm -f -- "$temporary_image"
  fi
}
trap cleanup EXIT

# CONFIG_TARGET_IMAGES_GZIP compresses QCOW2 images as *.qcow2.gz. Prefer the
# legacy BIOS image, then fall back to EFI; QEMU needs an uncompressed file.
image="$(find "$target_dir" -maxdepth 1 -type f \( \
  -name '*combined.qcow2' -o -name '*combined.qcow2.gz' \
\) -print -quit)"
efi_image=false

if [[ -z "$image" ]]; then
  image="$(find "$target_dir" -maxdepth 1 -type f \( \
    -name '*combined-efi.qcow2' -o -name '*combined-efi.qcow2.gz' \
  \) -print -quit)"
  efi_image=true
fi

if [[ -z "$image" ]]; then
  echo "No legacy or EFI QCOW2 image found in $target_dir" >&2
  find "$target_dir" -maxdepth 1 -type f -printf '%f\n' | sort >&2
  exit 1
fi

if [[ "$efi_image" == true ]]; then
  for firmware in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
    if [[ -f "$firmware" ]]; then
      firmware_args=(-bios "$firmware")
      break
    fi
  done
  if [[ "${#firmware_args[@]}" -eq 0 ]]; then
    echo 'EFI QCOW2 image found but no OVMF firmware was installed' >&2
    exit 1
  fi
fi

if [[ "$image" == *.qcow2.gz ]]; then
  temporary_image="$(mktemp --suffix=.qcow2)"
  gzip -dc -- "$image" > "$temporary_image"
  image="$temporary_image"
fi

echo "Using QCOW2 image: $image"

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
