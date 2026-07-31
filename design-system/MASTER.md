# TunnelChain Design System

**Category:** Developer tool / network utility  
**Style base:** Real-Time Monitoring + Dark Mode (OLED)  
**Stack:** Flutter (macOS desktop)  
**Generated from:** ui-ux-pro-max (Real-Time Monitoring, Developer Tool / IDE)

---

## Principles

1. **Data density over decoration** — diagnostics, metrics and verdicts are primary content.
2. **Status legibility** — `Running`, `Degraded`, `Failed` differ by color, icon and label (never color alone).
3. **macOS-native feel** — system font, 8pt grid, sidebar navigation, minimum 44×44 hit targets.
4. **Fail-safe communication** — warnings and destructive actions are explicit, not subtle.

---

## Color tokens

### Dark (default)

| Token | Hex | Usage |
|---|---|---|
| `background` | `#0D1117` | App background |
| `surface` | `#161B22` | Cards, sidebar |
| `surfaceElevated` | `#21262D` | Hover, selected row |
| `border` | `#30363D` | Dividers, outlines |
| `textPrimary` | `#E6EDF3` | Body, headings |
| `textSecondary` | `#8B949E` | Captions, metadata |
| `accent` | `#388BFD` | Links, focus, primary actions |
| `accentHover` | `#58A6FF` | Primary hover |

### Status (both themes)

| State | Color | Icon | Pattern |
|---|---|---|---|
| **Running** | `#3FB950` | `check_circle` | Solid dot + label «Connected» |
| **Degraded** | `#D29922` | `warning_amber` | Dashed ring + label «Degraded» |
| **Failed** | `#F85149` | `error_outline` | X mark + label «Failed» |
| **Stopped** | `#8B949E` | `radio_button_unchecked` | Hollow dot |

### Light

| Token | Hex |
|---|---|
| `background` | `#F6F8FA` |
| `surface` | `#FFFFFF` |
| `surfaceElevated` | `#F0F3F6` |
| `border` | `#D0D7DE` |
| `textPrimary` | `#1F2328` |
| `textSecondary` | `#656D76` |

---

## Typography

Use **system font** (SF Pro on macOS). No custom font files in v1.

| Role | Size | Weight | Line height |
|---|---|---|---|
| `display` | 22 | semibold (600) | 28 |
| `title` | 17 | semibold | 22 |
| `body` | 13 | regular | 18 |
| `caption` | 11 | regular | 14 |
| `mono` | 12 | regular (monospace) | 16 |

Monospace for: IP addresses, CIDRs, log lines, config tags.

---

## Spacing (8pt grid)

| Token | px |
|---|---|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |
| `xxl` | 32 |

Sidebar width: **220px**. Content max-width: unconstrained (data-dense tool).

---

## Radius & elevation

| Token | Value |
|---|---|
| `radiusSm` | 6 |
| `radiusMd` | 8 |
| `radiusLg` | 12 |

Cards: `radiusMd`, 1px border, no heavy shadow (flat monitoring UI).

---

## Components

### StatusBadge

Pill with icon + text. Always show text label (accessibility).

### VerdictCard

Diagnostics result: title, description, optional action button («Fix»).

### ChainDiagram

Horizontal hop flow: `VLESS → WireGuard` with protocol chips.

### PacketLayers

Vertical tree showing encryption layers (FR-29).

### SidebarNav

7 items matching FR-28: Status, Profiles, Proxy/VPN, Routing, DNS, Diagnostics, Logs.

---

## Motion

| Token | Duration | Curve |
|---|---|---|
| `fast` | 150ms | `easeOut` |
| `normal` | 200ms | `easeInOut` |
| `pulse` | 2000ms | infinite (live indicator only) |

Respect `prefers-reduced-motion`: disable pulse animation.

---

## Anti-patterns

- Marketing gradients and hero sections
- Status communicated by color dot only
- Low-contrast grey-on-grey for critical warnings
- Terminal/hacker aesthetic (reduces trust for network tooling)
- Hiding destructive actions (reset) behind menus

---

## Page specs

See `pages/` for screen-level layouts:

- [status.md](pages/status.md)
- [profiles.md](pages/profiles.md)
- [routing.md](pages/routing.md)
- [diagnostics.md](pages/diagnostics.md)

---

## Flutter mapping

Implementation: `lib/app/theme/` — `AppColors`, `AppTypography`, `AppTheme`, `TunnelStatusStyle`.
