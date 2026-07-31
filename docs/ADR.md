# ADR — Architecture Decision Records

**Project:** TunnelChain (working name)
**Related documents:** [FR.md](FR.md) · [AR.md](AR.md)

Context common to every decision: the application is a personal/internal tool, macOS first, with other platforms to follow.

---

## Index

| № | Decision | Status |
|---|---|---|
| [ADR-001](#adr-001) | Own application rather than a Hiddify fork | Accepted |
| [ADR-002](#adr-002) | Core as a separate process, no FFI linking | Accepted |
| [ADR-003](#adr-003) | Upstream sing-box, with a migration path to sing-box-lx | Accepted |
| [ADR-004](#adr-004) | Privileges via SMAppService, not NetworkExtension | Accepted |
| [ADR-005](#adr-005) | Default chain is VLESS, not WireGuard-in-VLESS | Accepted |
| [ADR-006](#adr-006) | MTU 1280 by default, tuned empirically | Accepted |
| [ADR-007](#adr-007) | Split DNS policy, interception by address and port | Accepted |
| [ADR-008](#adr-008) | Mandatory timed auto-rollback | Accepted |
| [ADR-009](#adr-009) | Flutter plus Riverpod | Accepted |
| [ADR-010](#adr-010) | UDP transport so all traffic can use a nested chain | Deferred |
| [ADR-011](#adr-011) | Design system via ui-ux-pro-max | Accepted |
| [ADR-012](#adr-012) | Chains and routing are independent entities | Accepted |
| [ADR-013](#adr-013) | Deliberate exit restores the system; one reset implementation | Accepted |

---

## ADR-001 {#adr-001}

### Own application rather than a Hiddify fork

**Status:** accepted

#### Context

Two paths were considered: forking [hiddify-app](https://github.com/hiddify/hiddify-app) (Flutter, 31.8k stars, 2821 commits, a mature sing-box client for five platforms), or writing an application from scratch.

Examining the Hiddify licence revealed material restrictions. It is **GPL v3 with additional Section 7 conditions**:

- commercial use, including sale and advertising, is prohibited without written consent;
- an obligation to publish fork source on GitHub and keep it current with releases;
- names and interfaces resembling Hiddify are prohibited;
- all releases must be produced through GitHub Actions.

#### Decision

Write an independent application. No code is taken from the Hiddify ecosystem.

#### Rationale

1. **The licence closes future options.** Even for a tool used privately today, a prohibition on commercial use plus mandatory fork publication are irreversible constraints. An independent application keeps the choice of licence open.
2. **Mismatch of purpose.** Hiddify is a general-purpose subscription client: managing server lists, refreshing profiles by URL, choosing among hundreds of nodes. The task here is narrow — chaining a handful of the user's own tunnels and routing between them. Most of the codebase is unnecessary, yet its presence must be maintained through every upstream rebase.
3. **Cost of familiarisation.** 2821 commits of somebody else's code built around a different model costs more than writing a purpose-built application, especially since the required core configuration is already known (the bash prototype works).
4. **Diagnostics are the core value.** `leakcheck`, `doctor`, MTU tuning, and distinguishing `Degraded` from `Running` are absent from Hiddify and do not fit its UX. They are the reason this product exists.

#### Consequences

- More upfront work: platform layer, helper, UI — all bespoke.
- No ready support for Android/iOS/Windows/Linux; these must be added.
- Full freedom over licence, architecture and UX.
- No inherited defects and no dependence on somebody else's release process.

#### Rejected alternatives

**Forking [Karing](https://github.com/KaringX/karing)** (Flutter plus a modified sing-box, macOS 12+, independent of Hiddify) — the licence is not stated clearly in the README, and the project carries VPN-provider partnership integrations and promotional material, which reproduces the same mismatch of purpose.

**Using a bash prototype as-is** — it works, but requires hand-editing environment variables, offers no observability, and is unusable by non-technical colleagues. The Flutter app replaces that workflow.

---

## ADR-002 {#adr-002}

### Core as a separate process, no FFI linking

**Status:** accepted

#### Context

`sing-box` is distributed under **GPL-3.0**. There are two ways to use it:

1. **Linking** — build it as a Go library and call it over FFI/CGO from Dart (Hiddify's approach: `hiddify-core` as a submodule).
2. **Process isolation** — run the prebuilt binary as a separate process, controlled through a configuration file and a REST API.

#### Decision

Process isolation. The application does not link the core; it launches it as a child process under launchd, passes configuration as a file, and reads state through the Clash API.

#### Rationale

1. **Licence boundary.** Under the settled reading of the GPL, arm's-length interaction — separate processes, pipes, sockets, CLI — does not create a derivative work, whereas linking does. Process isolation keeps our code free of copyleft, while GPL obligations remain with `sing-box` itself, whose sources are already public. The decision is irreversible, so drawing the boundary correctly from the start is cheaper than retrofitting it.
2. **Resilience.** A core crash does not take down the UI. Conversely, the UI can outlive and restart the core — significant given the observed rekey failures (see [AR §9.2](AR.md#92-wireguard-rekey-failure)).
3. **Upgradability.** The core is updated by replacing a binary (`brew upgrade sing-box`), with no application rebuild. Switching to `sing-box-lx` ([ADR-003](#adr-003)) becomes a file swap rather than a refactor.
4. **Proven.** The bash prototype works exactly this way, so the approach is known to be viable.

#### Consequences

- The lifecycle of an external process must be managed: start, stop, crash detection, log reading.
- Topology changes require rewriting configuration and restarting the core; switching between chains already present in the configuration goes through the API selector without a restart.
- The core binary must be distributed or its installation required. `brew install sing-box` suffices for local use; a distributed build embeds the binary in the bundle with GPL-3.0 attribution and a link to sources.
- The core's internal Go APIs are unavailable — only what configuration and the Clash API expose. In practice that is sufficient.

---

## ADR-003 {#adr-003}

### Upstream sing-box, with a migration path to sing-box-lx

**Status:** accepted

#### Context

Upstream `sing-box` speaks only vanilla WireGuard. AmneziaWG configurations with active obfuscation (`Jc≠0`, `S1`/`S2≠0`, non-standard `H1`–`H4`, any `I1`–`I5` present) do not connect — the handshake never completes.

[sing-box-lx](https://github.com/Leadaxe/sing-box-lx) is a thin fork (GPL-3.0) adding, behind individual build tags:

- **AmneziaWG 2.0** (`with_awg`) — `jc`/`jmin`/`jmax`, `s1`–`s4`, `h1`–`h4`, `i1`–`i5` promoted directly onto `WireGuardEndpointOptions`;
- **XHTTP** (`with_xhttp`) — Xray-compatible splithttp;
- **MASQUE** — CONNECT-IP over HTTP/3;
- **CommandClient** (`with_lx_command`) — gRPC observability: DNS queries, rules, outbounds;
- round-robin load balancing.

The fork states a "rebaseable on upstream tags" discipline: atomic commits, edits marked `// lx`, rebase rather than merge.

#### Decision

The **upstream** `sing-box` is the primary core. The architecture abstracts the core so that moving to `sing-box-lx` is a binary swap plus additional fields in the generator.

Migration triggers: (a) a configuration with active AWG obfuscation appears; (b) MASQUE UDP transport is needed to address TCP-over-TCP ([ADR-010](#adr-010)).

#### Rationale

- The upstream binary installs with one command, is signed, and updates cleanly; the fork requires building from source with submodules and a Go toolchain, which is an unnecessary barrier.
- The reference AWG configuration on hand contains **trivial** parameters (`Jc=0`, `S1=S2=0`), i.e. it is compatible with vanilla WireGuard — verified. There is no immediate need.
- A third-party fork is an additional trust vector for a tool that handles private keys. The switch should be deliberate.
- The application must **detect** incompatibility (FR-3) and explain it, rather than failing silently.

#### Consequences

- Configurations with active obfuscation require the alternative core; the application recognises this and explains it.
- The configuration generator is designed so AWG fields can be added without structural change — they sit at the same level as the other endpoint fields.
- Settings expose the path to the core binary, so a user can supply their own build.

---

## ADR-004 {#adr-004}

### Privileges via SMAppService, not NetworkExtension

**Status:** accepted

#### Context

Creating a TUN interface and editing routes on macOS requires root. The options:

1. **NetworkExtension** (`NEPacketTunnelProvider`) — Apple's sanctioned path. Requires Apple Developer Program membership and the `com.apple.developer.networking.networkextension` entitlement, granted on request.
2. **Privileged helper via `SMAppService`** (macOS 13+) — a daemon inside the bundle, registered by the system, communicating over XPC.
3. **`SMJobBless`** — the deprecated predecessor.
4. **A launchd daemon installed with `sudo`** — the bash prototype's approach.

#### Decision

`SMAppService` with a helper daemon and XPC. Option 4 remains a fallback for local development until signing is configured.

#### Rationale

- For a personal/internal tool there is no reason to pursue the NetworkExtension entitlement process.
- `SMAppService` is the current API (macOS 13+), the helper lives inside the bundle, and registration is visible to the user in System Settings — more honest than a silent `sudo` daemon.
- The launchd-daemon arrangement is already proven by the prototype, so the risks are understood.
- `SMJobBless` is deprecated and reportedly less reliable.

#### Consequences

- Minimum supported version is **macOS 13 Ventura**.
- Distribution requires a Developer ID signature; local builds use ad-hoc signing and manual registration.
- A Swift component is required: `main.swift`, the XPC service, `NetworkOps`, `ResetService`, `Watchdog`. This is the only platform-dependent code.
- The helper must verify the connecting client's code signing requirement, otherwise any process could control the network.
- Porting to Windows/Linux replaces only this layer.

#### Risks

There are reports of XPC instability with `SMAppService` daemons on recent macOS releases. Mitigation: helper health surfaced in the UI, clear re-registration instructions, and the launchd fallback.

---

## ADR-005 {#adr-005}

### Default chain is VLESS, not WireGuard-in-VLESS

**Status:** accepted

#### Context

The original requirement was for all traffic to travel inside WireGuard nested in VLESS — in model terms, designating such a chain as the default route. This was implemented in the prototype and **works**: nesting is confirmed experimentally.

Practical operation, however, exposed a fundamental problem. With all traffic through the nested chain the stack becomes: application TCP → WireGuard (UDP) → VLESS (**TCP**) → TCP to the VPS. This is TCP-over-TCP, with its well-known pathology:

- double congestion control: the outer TCP retransmits, and the inner TCP times out and retransmits as well; windows collapse geometrically;
- head-of-line blocking: losing one segment stalls the whole queue of WireGuard packets.

**Measured:** WireGuard.app on the same link — 10.5 MB/s. With the nested chain as default — 10 MB downloads fail with code `000`, ordinary traffic degrades, and disconnections recur.

#### Decision

The recommended default route is a chain consisting of **a single VLESS hop**; the chain with nested WireGuard is reached through overrides, for corporate subnets and suffixes.

The user may designate the nested chain as default (this is what "full tunnel" means elsewhere), but the application warns about the nature of the limitation. In model terms ([ADR-012](#adr-012)) this is a choice of `defaultTarget`, not a mode switch — modes do not exist as an entity.

#### Rationale

- This configuration preserves the **primary** requirement: there is no direct UDP to the corporate endpoint and the ISP cannot see WireGuard. Hiding the tunnel from the ISP is achieved either way.
- The bulk of traffic passes one encapsulation layer instead of two, so TCP-over-TCP never arises and throughput is close to plain VLESS.
- Corporate traffic is usually modest, so its slowdown is tolerable.
- Designating the nested chain as default is not removed: it is architecturally sound and becomes fully usable once the outer transport is UDP-based ([ADR-010](#adr-010)).

#### Consequences

- Personal traffic does not traverse the corporate network — a privacy gain, but a behavioural difference from WireGuard.app in full-tunnel mode that must be explained in the UI.
- A correct list of corporate subnets and domain suffixes is required, otherwise some resources become unreachable. Hence the auto-population and search-domain extraction requirements (FR-2, FR-11).
- The UI must show which traffic goes where; otherwise the user cannot understand why something is unavailable.

---

## ADR-006 {#adr-006}

### MTU 1280 by default, tuned empirically

**Status:** accepted

#### Context

Double encapsulation reduces the usable MTU. Arithmetic: `1500 − IP 20 − TCP 20 − TLS 22 − VLESS/xudp ~16 = 1422`; minus WireGuard 32 = **1390**.

1390 was applied in practice and **broke connectivity**: small connections worked while large transfers and TLS handshakes failed. The browser reported `DNS_PROBE_FINISHED_BAD_CONFIG`, because the DoH resolver could not complete its TLS handshake. 1280 turned out to work.

#### Decision

Default **1280** for both the TUN and WireGuard. The arithmetic maximum is not encoded in the product. The application provides a tuning tool and allows lower values (1200, 1150).

#### Rationale

- Empirical evidence outranks arithmetic: 1280 is the IPv6 minimum and the conventional value for nested tunnels, with headroom for PPPoE (1492) and TCP options.
- The outer layer is TCP and segments on its own, so an oversized MTU produces not a clean error but a black hole that is hard to attribute to MTU. A conservative default is therefore worth more than a theoretical maximum.
- The application must recognise the **symptom**: small requests succeed, large downloads stall.

#### Consequences

- Slightly more packets and overhead than theoretically possible.
- The UI gains an MTU tuning tool with an explicit recommendation to change one parameter at a time and measure.
- A process lesson recorded separately: changing several network parameters at once without measuring in between causes connectivity loss and difficult diagnosis.

---

## ADR-007 {#adr-007}

### Split DNS policy, interception by address and port

**Status:** accepted

#### Context

Three observations from operating the prototype:

1. **All DNS to a public DoH resolver** → internal names do not resolve and corporate resources are unreachable.
2. **All DNS to the corporate resolver** (reproducing WireGuard.app) → internal names work, but everything else "dies": the corporate resolver received 256 queries for one advertising domain, 250 for another, 235 for `google.com`; the logs filled with `dns: exchange failed ... context canceled`. The resolver could not cope, and every page waited for an answer through the double tunnel.
3. **DNS interception by a `protocol: dns` rule** without `{"action": "sniff"}` **does not work**: queries to the pinned address fall through to `route.final` and loop. The symptom is `DNS_PROBE_FINISHED_BAD_CONFIG`.

#### Decision

A split policy by query class:

| Class | Resolver |
|---|---|
| Corporate suffixes plus `*.in-addr.arpa` | the `.conf` resolver, through the inner hop |
| Public domains | DoH, through the outer hop |
| The VPS address | system resolver (bootstrap) |

Interception is expressed as a rule on **address and port** (`ip_cidr` plus `port: 53`), with `sniff` and `protocol: dns` retained as backstops.

An all-DNS-to-corporate option remains available, with warnings about resolver load and query-history visibility.

#### Rationale

- The split solves both problems at once: internal names resolve, and public queries do not load the corporate resolver.
- Interception by address and port does not depend on sniffing, which eliminates an entire class of failure.
- Search domains are mandatory: without them short names do not work, and that is precisely what WireGuard.app does invisibly.

#### Consequences

- A list of corporate suffixes is needed. Sources, in order of preference: the `DNS=` line in `.conf` (search domains), manual entry, log analysis for domains that resolved to private addresses.
- At least three DNS servers must be present in the configuration, or a circular dependency forms.
- The generator must guarantee rule ordering; this is covered by invariant tests.

**Field example:** internal suffixes such as `corp.internal` and `internal.example` — domains that resolve to private addresses through split-horizon DNS. The application should be able to discover such domains from private answers in the logs.

---

## ADR-008 {#adr-008}

### Mandatory timed auto-rollback

**Status:** accepted

#### Context

While debugging the prototype, a failed configuration left the machine without internet several times. The aggravating factor: **without connectivity the problem is hard to diagnose** — no documentation, no way to ask, no way to download a tool. Matters were worse because artifacts (a system proxy pointing at a dead port, a pinned DNS server) were not cleared on stop.

#### Decision

Applying a configuration always arms a watchdog. If the user does not confirm connectivity within the allotted time (5 minutes by default), the configuration is rolled back automatically: the core stops, and DNS, search domains, proxy settings and `pf` return to their previous state.

The watchdog runs as root, independently of the GUI. Confirmation is an explicit user action.

#### Rationale

- This is the only protection against "applied it, lost the network, cannot fix it".
- It mirrors an established practice: firewall changes over SSH are applied with an auto-revert timer.
- It removes the fear of experimenting — and without experiments, MTU and routing arrangements cannot be determined.

#### Consequences

- The user must confirm each apply — minor friction, justified by safety. The timer is configurable, including off.
- The watchdog cannot live in the GUI process: it must survive a GUI crash.
- Implementation is a root daemon checking a flag file or an XPC confirmation. The prototype proved the arrangement works, and that cancellation via a flag file requires no root.
- The watchdog shares its restore implementation with the explicit reset control ([ADR-013](#adr-013)).

---

## ADR-009 {#adr-009}

### Flutter plus Riverpod

**Status:** accepted

#### Context

Flutter is a given (macOS now, other platforms later). A state management approach is needed.

#### Decision

Flutter (stable) with **Riverpod** for state. Layering per [AR §3](AR.md#3-layers-and-responsibilities): UI → State → Domain, with an isolated `ConfigGenerator`.

#### Rationale

- Flutter delivers macOS now and a path to other platforms without rewriting the UI.
- Riverpod offers compile-time safety, straightforward provider testing, and natural handling of asynchronous streams (traffic and logs over the Clash API WebSocket) without requiring a `BuildContext`.
- The domain and the configuration generator are plain Dart with no Flutter dependency, making them fully testable.

#### Consequences

- Platform code in Swift is reached through platform channels/XPC — an expected boundary.
- Flutter on macOS requires Xcode; in the current environment **neither Flutter nor Xcode is installed**, which is the first implementation step.

#### Rejected alternatives

- **Swift plus SwiftUI** — more native and needs no bridge to the helper, but forecloses other platforms, contradicting the requirement.
- **Bloc** — more verbose at this scale; the additional rigour is not justified.

---

## ADR-010 {#adr-010}

### UDP transport so all traffic can use a nested chain

**Status:** deferred (recorded as a plan)

#### Context

Designating a chain with nested WireGuard as the default route is limited by TCP-over-TCP ([ADR-005](#adr-005)). Tuning cannot remove it: the problem is that VLESS/REALITY runs over TCP.

Making the outer layer UDP-based lets WireGuard travel over UDP, so double congestion control never arises and such a configuration becomes practical.

Candidate outer transports: **Hysteria2**, **TUIC** (both QUIC-based and supported by the upstream `sing-box`, whose build includes the `with_quic` tag), and **MASQUE** (CONNECT-IP over HTTP/3, available in `sing-box-lx`).

#### Decision

Deferred until it is established that routing by rules is insufficient. The architecture is prepared for the change: the outer hop of a chain is an abstraction, not tied to VLESS.

#### Rationale

- It requires server-side work: installing Hysteria2 alongside Xray, a separate port, a certificate. That is outside the application's control.
- The client side is already supported by the upstream core, so no rebuild is needed.
- Until it is demonstrated that routing by rules does not cover the need, investing in server-side plumbing is premature.

#### Consequences

- The `Chain` model must not assume the outer hop is VLESS.
- Documentation records that designating a nested chain as the default route is "usable with reservations", with the cause and the remedy stated.
- The migration will need Hysteria2/TUIC profile import — to be accounted for in the profile model.

---

## ADR-011 {#adr-011}

### Design system via ui-ux-pro-max

**Status:** accepted

#### Context

A modern interface is required. The specified tool is [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — **MIT**, generating design systems (84 styles, 192 palettes, 74 font pairings, UX rules and anti-patterns), supporting **Flutter** among 22 stacks, and depending only on the Python 3 standard library.

#### Decision

Use the skill to generate the design system up front. The result is committed to the repository (`design-system/MASTER.md` plus `pages/`) and serves as the source of truth for the UI.

Installation: `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill`, or `npm install -g ui-ux-pro-max-cli && uipro init --ai claude`.

#### Rationale

- MIT imposes no restrictions.
- Flutter support removes the need to hand-translate web tokens into Dart.
- A persisted design system in the repository keeps screens consistent and survives across development sessions.
- The rules and anti-patterns are the valuable part: the application displays a great deal of technical information (verdicts, measurements, states), where an overloaded interface is an easy failure mode.

#### Consequences

- The design system is generated once and committed; divergence between UI and design system counts as a defect.
- Product category for generation: developer tool / network utility, prioritising data density and status legibility over marketing vividness.
- Requirements layered on top of the generated output: dark and light themes, macOS-native spacing and typography, and `Running` / `Degraded` / `Failed` states distinguishable by more than colour (accessibility).

---

## ADR-012 {#adr-012}

### Chains and routing are independent entities

**Status:** accepted

#### Context

An earlier revision of these documents modelled configuration as "chain plus mode": the `Chain` entity carried a `mode` field with values `full`/`split`, and routing rules lived inside it. This was inherited from the bash prototype, where the mode was an environment variable.

That model has structural defects:

1. **Conflation of two orthogonal questions.** "How the channel is built" (which protocols, nested in what order) and "which traffic to send into it" are independent decisions. Merging them means a channel cannot be described without simultaneously deciding what it is for.
2. **`full`/`split` are a false abstraction.** They are not properties of a channel but two particular answers to "which chain is the default route". Introducing them as an entity creates a third concept where two suffice.
3. **Multiple channels are impossible.** With `mode` inside a chain one cannot have "internet via VPS" and "corporate network via WireGuard-in-VLESS" simultaneously — which is the primary use case.
4. **Duplication as configuration grows.** Adding a third channel (say, another VPS for a different region) would require copying rules into every chain.

#### Decision

Two independent entities and, correspondingly, two sections of the interface:

**Proxy/VPN** — chains. A named channel of one or more hops. Created, edited and deleted independently. Knows nothing about which traffic will use it. A single-hop chain is a fully supported case.

**Routing** — policy. One chain (or `direct`) is designated the default route; below it sits an ordered list of overrides, each sending matching traffic into a specific chain or into `direct`.

The `full`/`split` concepts are **removed from the model**. They survive only as preset names — operations that populate the routing policy with a typical set of values.

Additionally: **hops within one chain must not share a protocol**.

#### Rationale

- The model now matches the domain exactly: a channel and a rule for using it are different things.
- Multiple channels, and reuse of one channel by several rules, come for free.
- The third concept disappears: "mode" ceases to exist, leaving chains and rules.
- An "exclusion" (home LAN direct) stops being a special entity — it is an ordinary rule targeting `direct`.
- Presets provide the convenience of typical scenarios without becoming state that must be stored and synchronised.

**On forbidding duplicate protocols.** A `VLESS → VLESS` or `WG → WG` chain doubles overhead while adding neither obfuscation nor access to a new network — almost always user error. Deliberate trade-off: "double VLESS through two different VPS hosts" (geo change plus an extra layer) becomes unavailable. Should it be needed, the rule relaxes to a warning conditional on the hops pointing at **different servers**. As specified, the restriction is a hard rejection protecting against meaningless configurations.

#### Consequences

- `Chain` carries no `mode`; `RoutingPolicy`, `RoutingRule` and `RouteTarget` appear (see [AR §4](AR.md#4-data-model)).
- The generator addresses a chain by the tag of its **last** hop; other hops are reachable only through `detour`.
- `allowed_ips` on a WireGuard hop is computed by the generator from the routing policy rather than set by the user: `0.0.0.0/0` when the chain is the default, otherwise the union of the referencing rules' CIDRs.
- Only referenced chains reach the core configuration; unreferenced ones exist in the application without bloating it.
- The interface gains two sections instead of one, with navigation between them in both directions (FR-28).
- Deleting a chain requires checking rule references and offering reassignment.

#### Rejected alternatives

**Keep `mode` inside the chain and add "configuration profiles"** — retains the false abstraction and adds a fourth concept.

**Make routing a property of a profile rather than a chain** — breaks down for chains: it becomes unclear which hop owns the rule.

---

## ADR-013 {#adr-013}

### Deliberate exit restores the system; one reset implementation

**Status:** accepted

#### Context

The most damaging failure mode observed in practice is not a broken tunnel but **network configuration left pointing at a tunnel that no longer exists**. Concrete incidents:

- Hiddify was closed, but the system proxy at `127.0.0.1:12334` remained. `ping`, `dig` and `curl` kept working (they ignore the system proxy) while the browser and Postman failed with `ERR_PROXY_CONNECTION_FAILED`. Diagnosis went down the wrong path for a long time, because the obvious tools reported a healthy network.
- DNS pinned into a TUN that had already been torn down: name resolution silently stopped.
- `pf` rules left behind after the core was killed without cleanup.

In each case the user was left without a working network **and** without an obvious way to repair it.

A related asymmetry: a kill switch is deliberately fail-closed — when the core dies unexpectedly, traffic must not leak. But the same behaviour applied to a deliberate exit is a defect: the user closed the application on purpose and expects a working network.

#### Decision

Three commitments.

1. **Quitting the application fully restores network configuration.** Stop the core, restore DNS and search domains, clear proxy settings, drop `pf` rules, remove leftover routes, flush the DNS cache, disarm the watchdog.

2. **An explicit "Reset network settings" control** is always available, including while disconnected and while the core is unreachable, and works unconditionally regardless of internal state.

3. **One implementation for every path.** `ResetService` inside the helper is invoked by all four triggers: the explicit control, application quit, watchdog timeout, and the helper's own teardown.

Behavioural contract: **idempotent**; never fails because "there is nothing to reset"; executes every step even if an earlier one errors, reporting per-step outcomes.

#### Rationale

- One implementation means all paths restore the same set of settings. Separate code paths inevitably diverge, and the one used least often is the one that leaves artifacts behind.
- Idempotency matters because reset is most needed exactly when state is unknown — after a crash, after an external kill, after a reboot with an orphaned daemon.
- Executing every step despite errors: a partial reset is worse than none, because the user cannot tell what state the system is in.
- Invocation from the helper's teardown closes the last gap: even a GUI crash cannot leave the network broken.
- Distinguishing deliberate exit (fail-open) from unexpected core death (fail-closed) is what separates a safe tool from one that costs the user their internet.

#### Consequences

- Quit is intercepted: the application cannot terminate instantly, it must wait for the reset to complete. A progress indicator is required, and a forced-quit path if the reset hangs.
- Closing the last window is not quitting: the tunnel keeps running and the menu bar item remains. Only Quit triggers the reset.
- `Resetting` is an explicit state in the state machine ([AR §8.2](AR.md#82-state-machine)), not a transient — the user must see what is being restored.
- The reset is logged, making its effect auditable after the fact.
- A dedicated test level (AR §11): apply a configuration, call `resetAll`, assert the system is clean; repeat with the core already killed to prove idempotency.
- Overlap with Doctor (FR-22) is intentional: Doctor searches for artifacts left by *any* client including foreign ones, whereas reset unconditionally removes *our own*. Doctor diagnoses; reset guarantees.

#### Rejected alternatives

**Keep the tunnel running after quit (a background daemon).** Convenient in principle, but it is exactly what produces the "no internet and no idea why" state after a reboot or an update. If persistent operation is wanted later, it must be an explicit opt-in setting with a clear indicator, not the default.

**Rely on the watchdog alone.** The watchdog fires on timeout, not on exit. A user who quits after confirming a configuration would leave the system modified.

---

## Process lessons

These are not architectural decisions, but they explain why the diagnostic and safety requirements are as strict as they are. All were obtained on a live system.

| Lesson | How it manifested |
|---|---|
| Change one parameter at a time and measure | Changing MTU and network stack together broke connectivity; the cause had to be found by elimination |
| Arithmetic is not practice | The theoretically correct MTU of 1390 does not work |
| `ping` proves nothing | `gvisor` does not proxy ICMP; 100% loss with TCP working fine |
| Artifacts outlive the application | A Hiddify proxy on a dead port broke the browser while `ping` and `curl` kept working |
| No network blocks repair | Hence mandatory auto-rollback and an unconditional reset |
| The symptom can be far from the cause | `DNS_PROBE_FINISHED_BAD_CONFIG` resulted from an oversized MTU in one case and a missing `sniff` in another |
