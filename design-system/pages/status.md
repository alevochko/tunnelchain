# Status screen

**FR:** FR-28 (Status), FR-29 (chain visualisation)

## Layout

```
┌──────────────┬─────────────────────────────────────────────┐
│  Sidebar     │  Status                          [Connect]  │
│              ├─────────────────────────────────────────────┤
│              │  ● Running   External IP: 203.0.113.x       │
│              │                                             │
│              │  ┌─ Packet layers ─────────────────────┐    │
│              │  │ Application                          │    │
│              │  │  └─ WireGuard (corp)                 │    │
│              │  │      └─ VLESS REALITY (VPS)          │    │
│              │  │          └─ TCP to VPS               │    │
│              │  └──────────────────────────────────────┘    │
│              │                                             │
│              │  Traffic ▁▂▃▅▆  ↑ 1.2 MB/s  ↓ 4.5 MB/s     │
│              │                                             │
│              │  Active chain: Corp via VPS                │
│              │  Default route: VPS (VLESS)                 │
└──────────────┴─────────────────────────────────────────────┘
```

## States

- **Stopped** — Connect button primary; grey status badge.
- **AwaitingConfirm** — Countdown banner: «If connectivity is broken, do nothing — rollback in M:SS».
- **Degraded** — Amber badge + explanation («WireGuard handshake pending»).
- **Resetting** — Progress list of reset steps.

## Primary action

Connect / Disconnect toggle. Disabled while `Validating` or `Resetting`.
