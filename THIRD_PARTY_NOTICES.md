# Third-party notices

## sing-box

TunnelChain runs [sing-box](https://github.com/SagerNet/sing-box) as a **separate process**.
The application does not link against sing-box.

- **License:** GNU General Public License v3.0 (GPL-3.0)
- **Source:** https://github.com/SagerNet/sing-box
- **Bundled binary:** `TunnelChain.app/Contents/Resources/sing-box` (release builds)

To obtain sing-box source corresponding to the bundled version:

```bash
# Version pinned in macos/scripts/fetch_singbox.sh (SING_BOX_VERSION)
git clone https://github.com/SagerNet/sing-box.git
cd sing-box
git checkout v1.13.15
```

Or download release archives from:
https://github.com/SagerNet/sing-box/releases

## Flutter

- **License:** BSD-3-Clause
- **Source:** https://github.com/flutter/flutter
