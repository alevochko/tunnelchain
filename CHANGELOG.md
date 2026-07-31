# Changelog

All notable changes to TunnelChain are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-07-31

First public macOS release.

[Download DMG (arm64)](https://github.com/alevochko/tunnelchain/releases/download/v1.0.0/TunnelChain-1.0.0-macos-arm64.dmg) · [SHA256](https://github.com/alevochko/tunnelchain/releases/download/v1.0.0/TunnelChain-1.0.0-macos-arm64.dmg.sha256)

### Added

- **Nodes:** import VLESS (`vless://`, sing-box / Xray JSON) and WireGuard `.conf`; secrets in macOS Keychain
- **Chains:** ordered multi-hop tunnels (e.g. VLESS → WireGuard) with validation
- **Profiles:** split routing, per-rule DNS, import/export JSON bundles, clone
- **Connect:** sing-box config generation, TUN, DNS pin, menu bar control, traffic sparkline, log stream
- **Diagnostics:** nesting leak check, throughput probe, DNS checks, Doctor (process, proxy, DNS pin, pf, ICMP)
- **Safety:** auto-rollback watchdog, kill switch (signed helper), network reset, quit teardown
- **Bundled sing-box** 1.13.15 inside the app — no separate install
- Release scripts: `build_release.sh`, `create_dmg.sh`, GitHub Actions CI + Release workflow

### Known limitations

- **Unsigned DMG** — first launch via right-click → Open or `xattr -dr com.apple.quarantine`
- **Administrator password** on each Connect/Quit in unsigned (adhoc) builds
- **Apple Silicon only** for the pre-built GitHub DMG; Intel: build from source
- **Kill switch banner** requires signed helper + Login Items approval; adhoc builds fall back to Stopped
- No subscription URL import, Hysteria2/Trojan/Shadowsocks connect, or mobile clients yet — see [docs/ROADMAP.md](docs/ROADMAP.md)

### System requirements

- macOS 13+
- arm64 (M1/M2/M3…) for the release DMG

[1.0.0]: https://github.com/alevochko/tunnelchain/releases/tag/v1.0.0
