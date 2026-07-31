# Profiles screen

**FR:** FR-1, FR-2, FR-3, FR-4

## Layout

Toolbar: `[Import vless://]` `[Import .conf]`

List rows:
- Name, kind chip (VLESS / WireGuard)
- Endpoint summary (host:port or server name)
- Warning badge if AWG obfuscation active

## Secret display

Masked by default (`••••••••`), reveal on click. Never log or export cleartext.

## Import flow

1. Paste URL or pick file
2. Parse → preview fields
3. Save → secrets to Keychain, metadata to store
