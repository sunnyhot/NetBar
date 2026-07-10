# NetBar Network Health And Smart Menu Bar Design

## Overview

This design adds an explainable network-health layer to NetBar and uses that layer to improve both the details popover and the smart menu bar experience.

The approved product direction is:

- A user should understand the current network situation within three seconds.
- The details popover remains a compact realtime instrument, with the traffic chart as its visual anchor.
- A health summary directly below the chart explains connection quality, evidence, the primary cause, and the recommended action.
- The menu bar provides balanced ambient feedback through restrained color, character, animation, and short status changes.
- Active network checks are opt-in and adapt their frequency to visibility, degradation, power state, and sleep state.
- Health is expressed as `good`, `fluctuating`, `poor`, or `offline`; NetBar does not show a pseudo-precise 0–100 score.

## Goals

- Let users distinguish normal activity from degraded connectivity without opening Activity Monitor or another network tool.
- Keep the existing realtime traffic identity while reducing the current long sequence of equally weighted popover sections.
- Use one explainable health snapshot for the details popover, status bar text, status bar color, smart character recommendation, and animation behavior.
- Preserve user control: smart rendering never overwrites the user's stored menu bar layout, color, or character preferences.
- Keep active checks transparent, low-frequency, cancellable, and disabled by default.
- Preserve NetBar's no-packet-capture, no-admin-access, no-third-party-dependency posture.

## Non-Goals

- No long-term active-probe history or latency analytics database.
- No custom probe target editor in this version.
- No rule-builder for mapping arbitrary states to menu bar characters.
- No ICMP implementation and no claim of measuring exact packet loss.
- No new system notifications for health-state changes in this version.
- No redesign of the CoreGraphics menu bar layout engine.
- No change to network traffic accounting, application attribution, history retention, update installation, packaging, or RunCat assets.

## Approved Experience

### Details Popover

The details popover keeps the current anchored, transient, menu-bar-sized window and the existing restrained macOS-native visual system.

The selected layout is **realtime signal first**:

1. Compact activity header with current interface and download, upload, and total throughput.
2. Realtime download/upload chart as the visual anchor.
3. Network-health summary with state, evidence freshness, connection latency, DNS duration, recent failure count, and a manual retest action.
4. Primary activity/cause and recommended action.
5. Expandable evidence groups for application usage, interfaces/VPN/attribution, and history/system resources.
6. Existing footer actions.

The first visible screen must answer:

- What is happening now?
- Is connectivity good, fluctuating, poor, or offline?
- What evidence supports that conclusion?
- What should the user do next?

The current popover content is reorganized rather than removed:

- Application Top and Application Traffic become one application-usage group.
- Interface details, VPN/proxy attribution, and system-resource evidence become one interface-diagnostics group.
- Today, seven-day history, and the insight stream become one historical-evidence group.
- The chart, health summary, primary cause, and recommendation remain immediately visible.

### Before Active Diagnostics Consent

Active diagnostics are disabled by default. Before consent, the health summary uses local evidence only and says:

- Chinese: `本地网络状态正常` and `未检测公网质量`.
- English: `Local network looks normal` and `Internet quality not checked`.

The enable action opens a confirmation sheet that states:

- NetBar will resolve and connect to the existing GitHub origin already used for updates.
- Checks measure DNS duration, HTTPS connection/response latency, and recent success/failure counts.
- No traffic content, application list, browsing history, or local network statistics are uploaded.
- The feature can be disabled at any time.

The setting becomes enabled only after explicit confirmation.

### With Active Diagnostics Enabled

The health summary shows:

- One of four health states.
- Connection/response latency in milliseconds.
- DNS resolution duration in milliseconds.
- Recent active-check failures as a count, such as `0 / 5`.
- The last successful or attempted check time.
- `Retest Now` / `立即复测`.
- A disclosure/evidence detail explaining which measurements affected the conclusion.

The UI labels recent failures as failures, not packet loss.

## Unified Health Model

### Types

`NetworkHealthState` has four cases:

- `good`
- `fluctuating`
- `poor`
- `offline`

`NetworkHealthEvidenceMode` describes whether a state is based on:

- `localOnly`: interface, path, traffic, and existing anomaly data only.
- `active`: a fresh opt-in probe result is available.
- `paused`: automatic probes are paused for low power, lock, or sleep.
- `unavailable`: active diagnostics are enabled but the evidence is stale or the reference target cannot currently provide a trustworthy result.

`NetworkHealthSnapshot` contains:

- `state`
- `evidenceMode`
- `primaryCause`
- `metrics`
- `recommendation`
- `notices`
- `sampledAt`
- `expiresAt`
- `isRetestInProgress`

`NetworkHealthMetrics` contains optional DNS duration, connection/response latency, recent attempt count, recent failure count, and local path/interface availability.

`NetworkHealthNotice` carries non-quality information such as high traffic, application spikes, proxy/VPN attribution gaps, and recovery events. Notices can affect menu bar emphasis or character choice but do not automatically lower the health state.

### Ownership

The new health units have narrow responsibilities:

- `NetworkHealthProbing`: injectable protocol for one active diagnostic attempt.
- `LiveNetworkHealthProbe`: system implementation using Foundation networking and the system resolver; it does not shell out to `ping`.
- `NetworkHealthEvaluator`: pure rule evaluation and presentation-independent hysteresis.
- `NetworkHealthCoordinator`: adaptive scheduling, cancellation, recent-sample window, manual retest cooldown, and lifecycle reactions.
- `NetworkMonitor`: exposes the coordinator's latest `NetworkHealthSnapshot` as published state alongside existing snapshots.

The evaluator receives values; it does not start work, read preferences, or mutate UI state. The coordinator schedules work; it does not decide colors, characters, or copy.

## Active Diagnostic Probe

### Reference Target

Version 1 reuses `github.com`, which NetBar already contacts for update metadata, instead of adding a new third-party diagnostics provider.

Each attempt performs:

1. A timed system DNS resolution for `github.com`.
2. An ephemeral HTTPS `HEAD` request to `https://github.com/` with a short timeout.
3. Timing until a valid HTTP response is received. Any HTTP response proves reference reachability; its status code does not represent NetBar health.

The ephemeral session does not persist cookies, credentials, or URL cache data. The request includes no NetBar-collected traffic or application data.

GitHub is a reference target, not a claim about the entire internet. When the macOS network path remains available, expected DNS, timeout, and connection failures can produce `fluctuating` or `poor` with a cause that explicitly names reference reachability; they never produce `offline`. Probe cancellation, expired evidence, or an internal/configuration failure that cannot describe network quality produces `unavailable` instead.

### Scheduling

Automatic active diagnostics run only when enabled:

- Normal background interval: 60 seconds.
- Details popover visible: 15 seconds.
- Degraded state verification: 10 seconds for at most 2 minutes, then return to the normal interval unless the popover remains visible.
- Low Power Mode: automatic checks pause.
- Screen locked or sleeping: automatic checks pause and outstanding work is cancelled.
- Wake/unlock: run an immediate check if enabled and the previous evidence is expired.

A user-initiated retest is allowed while awake, including in Low Power Mode. It has a 10-second cooldown and cannot overlap an existing attempt.

The coordinator attaches `expiresAt` to each result based on the active schedule. Expired active evidence never silently remains part of a current health conclusion.

## Health Evaluation

The evaluator uses conservative thresholds and hysteresis so that the menu bar does not flap.

### Immediate Offline Evidence

`offline` is immediate only when macOS reports an unsatisfied network path or there is no eligible external network interface.

Reference-target failures alone do not produce `offline`. When the local path remains available, repeated target failures produce `poor` or `unavailable` evidence.

### Active Quality Defaults

The evaluator examines the rolling five most recent attempts:

- Candidate `good`: latest attempt succeeds, recent failures are `0 / 5`, DNS is below 400 ms, and response latency is below 600 ms.
- Candidate `fluctuating`: one recent failure, DNS from 400–999 ms, response latency from 600–1499 ms, or a single mild local-path transition.
- Candidate `poor`: two or more recent expected DNS/timeout/connection failures, DNS at least 1000 ms, response latency at least 1500 ms, or repeated connectivity-related anomaly evidence.

High throughput, application spikes, or proxy attribution gaps become notices and causes; they do not by themselves change `good` to `poor`.

### Hysteresis

- An immediate offline condition bypasses hysteresis.
- Other degradations require two consecutive candidate evaluations before promotion.
- Recovery to `good` requires three consecutive good candidate evaluations.
- A recovered state may emit a temporary recovery notice without changing the final `good` state.

Thresholds live in a single `NetworkHealthThresholds` value so tests can inject boundary values without spreading constants across the codebase.

## Smart Menu Bar Feedback

The existing conservative preferences remain authoritative:

- `isSmartStatusBarModeEnabled` controls smart text/display emphasis.
- `isSmartCharacterSuggestionEnabled` controls character overrides.
- Both remain disabled by default and decode safely from older settings.

The balanced mapping is:

| Health state | Tone | Text behavior | Character behavior | Animation behavior |
|---|---|---|---|---|
| Good | User-selected/default signal tone | Preserve the user's traffic layout | Preserve the user's selected or rotating character | Continue normal traffic-driven animation |
| Fluctuating | Amber accent | Short cause such as `延迟波动` / `Latency fluctuating` when smart status is enabled | Cause-based suggestion, normally `little_cloud` for DNS/latency | Slight emphasis only; no rapid pulse |
| Poor | Coral/critical accent | Short cause such as `连接较差` / `Poor connection` | Cause-based suggestion; reuse current application-spike/high-traffic mappings for notices | Slow and deliberate; do not create frantic motion |
| Offline | Critical red marker | `网络离线` / `Offline` | `little_cloud` when smart characters are enabled | Pause character animation |

Existing cause-based suggestions remain valid:

- Application spike: `shiba_inu`.
- High traffic: `penguin`.
- Recovery: `bunny`.
- Idle: `tiny_plant`.
- Connectivity, DNS, network-drop, or attribution issue: `little_cloud`.

Health state sets tone and animation policy. The primary cause or notice chooses the character and short label. Smart overrides are render-time values and never write back to `StatusBarSettings` or the user's stored character choice.

## Preferences

Add an `Active Network Diagnostics` / `主动网络质量诊断` row to the Intelligence preferences section.

The row includes:

- An off-by-default toggle.
- A short privacy explanation.
- The disclosed reference host, `github.com`.
- Current status: disabled, waiting, active, paused for power, paused for sleep, or temporarily unavailable.
- A `Retest Now` action when enabled and awake.

`NetworkIntelligenceSettings` gains `isActiveNetworkDiagnosticsEnabled`, defaulting to `false` when decoding older settings. The existing smart status bar and smart character toggles stay in the Menu Bar preferences and control whether health affects those surfaces.

## Error Handling

- Timeout, cancellation, DNS failure, and transport failure produce typed probe results rather than user-facing raw errors.
- Cancelling due to sleep, lock, disabling the setting, or coordinator shutdown is not counted as a failed network attempt.
- Expected reference DNS, timeout, or connection failures with a satisfied local path may produce `fluctuating` or `poor`, with copy that names the reference limitation; they never produce `offline`.
- Probe cancellation, stale evidence, or an internal/configuration error that cannot support a quality conclusion produces `unavailable`.
- Stale active evidence is visibly marked and excluded from current quality thresholds.
- Manual retest shows progress, respects cooldown, and cannot create concurrent requests.
- If the app cannot determine a trustworthy state, it says `暂无法判断` / `Unable to determine`, while still showing local interface and traffic evidence.
- All new user-facing strings use the existing Chinese/English dual-string helpers.
- Looping pulse or scan effects remain disabled when Reduce Motion is enabled.

## Data Flow

```text
NetworkSnapshot / ApplicationTrafficState / NetworkIntelligenceSummary
macOS path, power, lock and sleep state
                       │
                       ├──────── passive evidence ────────┐
                       │                                  │
opt-in NetworkHealthProbe ─ recent active samples ───────┤
                                                          ▼
                                            NetworkHealthEvaluator
                                                          │
                                                          ▼
                                             NetworkHealthSnapshot
                                               │                 │
                                               ▼                 ▼
                                      NetworkPopoverView   StatusBarContextEvaluator
                                                               │
                                                               ▼
                                                    text / tone / character / motion
```

## File Boundaries

### New Files

- `Sources/NetBar/NetworkHealthModels.swift`
- `Sources/NetBar/NetworkHealthProbe.swift`
- `Sources/NetBar/NetworkHealthEvaluator.swift`
- `Sources/NetBar/NetworkHealthCoordinator.swift`
- `Sources/NetBar/Popover/NetworkHealthPanel.swift`
- `Tests/NetBarTests/NetworkHealthTests.swift`

### Modified Files

- `Sources/NetBar/NetworkMonitor.swift`: publish and feed local evidence to the health coordinator.
- `Sources/NetBar/PerformanceSamplingPolicy.swift`: expose or reuse visibility, low-power, lock, and sleep inputs for diagnostic scheduling.
- `Sources/NetBar/NetworkIntelligenceModels.swift`: persist the opt-in diagnostics setting with backward-compatible decoding.
- `Sources/NetBar/StatusBarContextEvaluator.swift`: consume health state and notices for smart emphasis and character suggestions.
- `Sources/NetBar/StatusBarController.swift`: pass health context into render-time smart overrides and motion policy.
- `Sources/NetBar/Popover/NetworkPopoverView.swift`: place chart first, then the health panel, and reorganize evidence groups.
- Existing `Sources/NetBar/Popover/*Panel.swift` files: expose content through the approved grouped/collapsible information hierarchy.
- `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`: add the opt-in control, disclosure, status, and retest action.
- `Tests/NetBarTests/PreferencesAndPresentationTests.swift`: settings compatibility, status bar mappings, bilingual source boundaries, and popover structure.
- `Tests/NetBarTests/SystemResourceTests.swift`: integration coverage where the monitor owns diagnostic scheduling lifecycle.

No new dependency, package, entitlement, helper process, background daemon, resource asset, or update format is introduced.

## Testing

### Unit Tests

- State threshold boundaries for DNS, response latency, and recent failures.
- Immediate offline behavior for unsatisfied path or missing external interface.
- GitHub reference failure with a satisfied local path does not become offline.
- High traffic, application spikes, and proxy attribution gaps remain notices rather than health degradation.
- Two-sample degradation hysteresis and three-sample recovery hysteresis.
- Stale, local-only, paused, unavailable, and fresh-active evidence modes.
- Probe success, HTTP response, DNS failure, timeout, transport failure, and cancellation mapping.
- Scheduler intervals for background, visible popover, verification burst, low power, sleep, wake, and manual retest cooldown.
- Manual retest cannot overlap an in-flight request.
- Smart status mapping for all four health states.
- Smart character behavior respects `isSmartCharacterSuggestionEnabled`.
- Smart status behavior respects `isSmartStatusBarModeEnabled`.
- Render-time overrides do not mutate stored preferences.
- Older persisted settings decode with active diagnostics disabled.

### Project Verification

Run:

```bash
swift test
./Scripts/build-app.sh
./Scripts/verify-release-app.sh build/NetBar.app
```

### Manual Visual QA

- Light and dark appearances.
- Chinese and English.
- Active diagnostics disabled, consent sheet, enabled, checking, paused, unavailable, and disabled again.
- Good, fluctuating, poor, and offline presentations.
- Menu bar with smart status disabled/enabled and smart characters disabled/enabled.
- Existing manual character, rotating character, custom character, and no-character layouts.
- Reduce Motion enabled.
- Popover at minimum and preferred heights.
- Low Power Mode pause and wake/unlock refresh.

## Acceptance Criteria

- The chart remains the popover's primary visual instrument.
- The first popover screen communicates activity, health state, evidence, primary cause, and next action.
- Health is expressed with four named states and no numeric score.
- Active diagnostics never run before explicit consent and are disabled by default for existing and new users.
- Local-only mode does not claim that internet quality was measured.
- GitHub reference failure alone cannot produce an offline state.
- High traffic is not mislabeled as poor network health.
- Menu bar feedback is balanced, stable, and driven by the same snapshot as the popover.
- Disabling smart status or smart characters restores user-controlled rendering immediately.
- No smart override persists into the user's stored layout, color, or character preferences.
- All new copy is bilingual and readable in light and dark appearances.
- Existing tests and the new health tests pass.
- The app builds and passes the repository's release-app verification script.
