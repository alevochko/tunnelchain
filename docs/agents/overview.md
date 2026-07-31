# Project overview and domain model

TunnelChain is a macOS app for managing **VPN/proxy tunnel chains** with split routing. It generates a [sing-box](https://github.com/SagerNet/sing-box) config, brings up a single TUN interface, and manages DNS and routes through a privileged helper.

---

## Why it exists

Standard macOS VPN clients conflict: each creates its own `utun`, rewrites DNS, and cannot nest WireGuard inside VLESS across separate apps.

TunnelChain solves this with **one core process**, **one TUN**, and **one owner of routes and DNS**.

---

## Core entities

| Entity | Description | Storage |
|--------|-------------|---------|
| **Node (Profile)** | A single endpoint: VLESS or WireGuard | `profiles.json` + Keychain for secrets |
| **Chain** | Ordered hops, outer → inner | `tunnel_plan.json` |
| **Connection Profile** | Routing + DNS, references chains | `tunnel_plan.json` |
| **Active profile** | Profile used on connect | runtime state |
| **TunnelConfig** | MTU, log level, clash API port, etc. | settings |

**Important:** in the UI, "Profiles" = routing profiles; "Nodes" = endpoint profiles. In code both are `Profile`, distinguished by `ProfileKind`.

### Invariants (validators)

- Chain: no two hops of the same protocol (`VLESS→VLESS`, `WG→WG`).
- Chain: no duplicate profile id in hops.
- Chain: all hop profile ids must exist.
- Routing: override rules reference existing chains.
- No hard-coded "full tunnel" / "split" — that emerges from default chain + overrides.

Validators: `chain_validator.dart`, `routing_validator.dart`.

---

## Connect flow

```
UI (Status)
  → tunnel_session / connect_bundle
  → TunnelConnectBuilder assembles profiles + chains + routing + dns
  → ConfigGenerator → config.json (0600)
  → CoreController → helper starts sing-box
  → ClashApiClient — traffic, logs, WS
```

Disconnect / quit / watchdog timeout → **one** `ResetService` path to restore DNS/proxy/routes.

---

## Secrets

- In models: `SecretRef('keychain.key')`, not the secret string.
- On import: `ParseResult.secrets` → `KeychainStore.write`.
- On config generation: `SecretResolver` (runtime) injects values in memory only for sing-box.
- Bundle export: secrets follow transfer service policy (refs, not plain text in the normal flow).

---

## Supported protocols (current state)

| Protocol | Import | Connect | Notes |
|----------|--------|---------|-------|
| VLESS | ✅ URI + Xray/sing-box JSON | ✅ | TCP, gRPC, WS, H2, HTTPUpgrade; TLS, REALITY |
| WireGuard | ✅ `.conf` | ✅ | |
| AmneziaWG | ⚠️ detect | ❌ | obfuscation in model; generator — roadmap |
| Hysteria2, Trojan, SS, SOCKS | ❌ UI disabled | ❌ | roadmap phase 3 |
| Subscription URL | ❌ | ❌ | roadmap phase 2 |

Current plan: [ROADMAP.md](../ROADMAP.md).

---

## UI navigation

| Screen | Route | Purpose |
|--------|-------|---------|
| Status | `/` | connect, traffic, packet layers |
| Profiles | `/routing` | routing + DNS profiles |
| Chains | `/proxies` | compose hops |
| Nodes | `/profiles` | import endpoints |
| Diagnostics | `/diagnostics` | leak, MTU (partial) |
| Logs | `/logs` | sing-box stream |

Router: `lib/app/router.dart`. Shell: `AppShell`.

---

## Out of scope (do not implement without explicit request)

- iOS / Android / Windows ports
- Background subscription auto-update
- Load balancer / selector outbounds
- Forking Hiddify
- Linking sing-box (FFI)

---

## Glossary

| Term | Meaning |
|------|---------|
| Hop | One node inside a chain |
| Outer hop | First in chain — closer to the internet |
| Inner hop | Last in chain — closer to the application |
| Default route | Chain for traffic without an override |
| Override | Rule: if matcher matches → use chain X |
| Helper | Root daemon `TunnelChainHelper` |
| Core | sing-box process |
