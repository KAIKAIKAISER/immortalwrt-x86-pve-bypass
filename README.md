# ImmortalWrt x86_64 PVE bypass router

Reproducible ImmortalWrt firmware for Proxmox VE with IPv4/IPv6, AdGuard Home,
OpenClash/Mihomo, common LuCI themes, and scheduled upstream synchronization.

## Included

- ImmortalWrt stable `24.10.x`, automatically following patch releases only.
- PVE-friendly legacy BIOS and UEFI QCOW2 images.
- VirtIO support and QEMU Guest Agent.
- LuCI in Simplified Chinese.
- Argon, Bootstrap, Material, and OpenWrt 2020 themes.
- AdGuard Home with AdGuard DNS Filter and anti-AD.
- OpenClash with an x86_64 Mihomo core, IPv6 enabled, and no embedded subscription.
- Weekly upstream checks and immutable GitHub Releases.

## Default network behavior

- Management IPv4: `192.168.1.2/24`
- Upstream gateway: `192.168.1.1`
- IPv4 DHCP server: disabled
- IPv6: enabled; a unique ULA `/48` is generated at first boot
- IPv6 RA advertises DNS but does not claim the default route
- DNS path: client -> dnsmasq `:53` -> AdGuard Home `:5335` -> OpenClash `:7874`
- If OpenClash is not running, AdGuard Home falls back to AliDNS/DNSPod DoH

Change the management address from the PVE console before attaching the VM to a
LAN where `192.168.1.2` is already in use.

For every client to use this DNS service, configure the main router's DHCPv4 DNS
option and IPv6 RDNSS/DHCPv6 DNS to point to this VM. Disable competing DNS
advertisements on the main router. Plain DNS interception only applies to clients
whose gateway traffic traverses this VM; DoH cannot be completely intercepted by
port rules alone.

## PVE import

Download and verify `SHA256SUMS`, then decompress the desired `qcow2.zst` file.
Example commands on the PVE host:

```sh
zstd -d immortalwrt-*-combined-efi.qcow2.zst
qm create 120 --name immortalwrt-bypass --memory 2048 --cores 2 --cpu host
qm importdisk 120 immortalwrt-*-combined-efi.qcow2 local-lvm
```

Attach the imported disk as SCSI with `VirtIO SCSI single`, add one or two VirtIO
NICs, and choose OVMF for the EFI image or SeaBIOS for the legacy image.

## Services after first boot

- LuCI: `https://192.168.1.2/`
- AdGuard Home: `http://192.168.1.2:3000/`
- OpenClash: LuCI -> Services -> OpenClash

The image intentionally has no proxy subscription. Add one in OpenClash, verify
the generated configuration, and then enable OpenClash.

## Automation

The workflow runs every Sunday at 03:37 Asia/Shanghai and can also be started
manually. It resolves the latest stable `24.10.x` tag, latest OpenClash release,
and current official OpenClash core commit. If that fingerprint already has a
Release, the scheduled build exits without compiling.

Major ImmortalWrt upgrades are deliberately not automatic.

## Security

- No account password, proxy subscription, token, or private key is committed.
- External source revisions are recorded in each Release.
- Official reusable Actions are pinned to commit SHAs.
- Build output includes resolved configuration, feeds lock, metadata, manifest,
  and SHA-256 checksums.
