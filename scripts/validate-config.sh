#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-.config}"
required=(
  CONFIG_TARGET_x86_64
  CONFIG_GRUB_IMAGES
  CONFIG_GRUB_EFI_IMAGES
  CONFIG_QCOW2_IMAGES
  CONFIG_PACKAGE_adguardhome
  CONFIG_PACKAGE_dnsmasq-full
  CONFIG_PACKAGE_luci-app-openclash
  CONFIG_PACKAGE_luci-ssl-openssl
  CONFIG_PACKAGE_luci-theme-argon
  CONFIG_PACKAGE_luci-theme-bootstrap
  CONFIG_PACKAGE_qemu-ga
  CONFIG_PACKAGE_kmod-nft-tproxy
  CONFIG_PACKAGE_kmod-tun
)

failed=0
for symbol in "${required[@]}"; do
  if ! grep -qx "${symbol}=y" "$config_file"; then
    echo "Required symbol missing after defconfig: ${symbol}=y" >&2
    failed=1
  fi
done

if grep -qx 'CONFIG_PACKAGE_dnsmasq=y' "$config_file"; then
  echo 'dnsmasq and dnsmasq-full cannot both be selected' >&2
  failed=1
fi

if grep -qx 'CONFIG_PACKAGE_libustream-mbedtls=y' "$config_file"; then
  echo 'libustream-mbedtls conflicts with the default libustream-openssl backend' >&2
  failed=1
fi

exit "$failed"
