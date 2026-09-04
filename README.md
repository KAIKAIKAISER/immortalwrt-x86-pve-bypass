# ImmortalWrt x86_64 PVE bypass router

Reproducible ImmortalWrt firmware for Proxmox VE with IPv4/IPv6, AdGuard Home,
OpenClash/Mihomo, common LuCI themes, and scheduled upstream synchronization.

## Included

- ImmortalWrt stable `24.10.x`, automatically following patch releases only.
- One PVE-friendly legacy BIOS raw disk image (`combined.img.gz`), matching a
  SeaBIOS + `scsi0` VM layout.
- VirtIO support and QEMU Guest Agent.
- LuCI in Simplified Chinese.
- Argon, Bootstrap, Material, and OpenWrt 2020 themes.
- AdGuard Home with AdGuard DNS Filter and anti-AD.
- OpenClash with an x86_64 Mihomo core, IPv6 enabled, and no embedded subscription.
- Mainland-China defaults: NJU ImmortalWrt package mirror, AliDNS/Tencent DNS,
  360 DoH fallback, and the anti-AD China filter endpoint.
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

Download and verify `SHA256SUMS`, then decompress the single `combined.img.gz`
file. This build intentionally does not produce ISO, EFI, or QCOW2 variants in
order to reduce GitHub Actions build time.
Example commands on the PVE host:

```sh
gunzip immortalwrt-*-combined.img.gz
qm create 120 --name immortalwrt-bypass --memory 2048 --cores 2 --cpu host
qm importdisk 120 immortalwrt-*-combined.img local-lvm
```

Attach the imported disk as `scsi0` with `VirtIO SCSI single`, add one or two
VirtIO NICs, and keep the VM BIOS as SeaBIOS. If QEMU Guest Agent is enabled in
PVE, enable it with `qm set 120 --agent enabled=1`.

## Services after first boot

- LuCI: `https://192.168.1.2/`
- AdGuard Home: `http://192.168.1.2:3000/`
- OpenClash: LuCI -> Services -> OpenClash

Immediately set a strong ImmortalWrt `root` password with `passwd` from the PVE
console or in LuCI. The preloaded AdGuard Home configuration also starts without
a web administrator; create one before exposing port `3000` beyond the trusted
LAN. No shared default credentials are embedded in the image.

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
