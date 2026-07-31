# Diagnostics screen

**FR:** FR-18…FR-23, FR-25

## Sections

1. **Reset network settings** — always visible, destructive styling.
2. **Nesting check** (leakcheck) — verdict card.
3. **MTU tuning** — current value, test, recommendations.
4. **Throughput** — avg / best / failed runs.
5. **DNS test** — public vs corporate resolvers.
6. **Doctor** — findings list with per-item Fix.

## Verdict pattern

```
┌─────────────────────────────────────┐
│ ✓  Nesting confirmed                │
│    No direct UDP to corp endpoint   │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ✗  Direct UDP detected              │
│    Nesting is broken                │
│                        [Run again]  │
└─────────────────────────────────────┘
```

Icons + color + text (accessibility).
