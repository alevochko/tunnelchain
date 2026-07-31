# Routing screen

**FR:** FR-10, FR-11, FR-12

## Layout

```
Default route:  [ VPS (VLESS)        ▼ ]

Presets:  [Corporate access] [Everything via corp] [Corp only]

Overrides (drag to reorder):
  ┌────────────────────────────────────────────────┐
  │ ≡  10.0.0.0/8, 172.20.0.0/16  →  Corp via VPS │
  │ ≡  *.corp.internal, *.internal.example  →  Corp via VPS │
  │ ≡  192.168.1.0/24             →  direct       │
  └────────────────────────────────────────────────┘
  [+ Add rule]
```

## Warnings

- Default = nested WG chain → TCP-over-TCP warning card (ADR-005).
- Deleted chain referenced → reassignment dialog.
