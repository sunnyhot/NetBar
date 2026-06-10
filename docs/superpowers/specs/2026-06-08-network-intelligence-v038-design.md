# NetBar v0.38.0 Network Intelligence Design

## Overview

v0.38.0 is a combined "Network Intelligence" release. It turns NetBar from a live network speed display into a local network awareness tool that can answer:

- Is my network behavior normal right now?
- Which app is using traffic?
- What happened today?
- Should NetBar notify me or simply explain the situation in the app?

The release intentionally keeps NetBar's existing positioning:

- Local-first macOS menu bar app
- No packet capture
- No network content inspection
- No administrator permission requirement
- Lightweight AppKit + SwiftUI implementation

The implementation is one public version, built in three internal phases:

1. Data layer: anomaly detection, history summaries, realtime and daily app Top.
2. Experience layer: details window, preferences, notification onboarding, menu bar presets.
3. Differentiation layer: pet cues, character linkage, release polish, full verification.

## Goals

- Detect and explain common network anomalies without reading packet contents.
- Show today's estimated network usage and the last 7 daily summaries.
- Show both realtime Top apps and today's cumulative Top apps.
- Provide first-run notification onboarding for v0.38.0.
- Provide built-in menu bar presets without adding custom preset management.
- Make the pet/character system feel useful during anomalies while remaining lightweight.

## Non-Goals

- No packet capture or protocol inspection.
- No firewall, blocking, throttling, or per-app network control.
- No long-term monthly analytics.
- No cloud sync or external telemetry.
- No custom user-saved menu bar presets in v0.38.0.
- No complex pet progression, store, levels, or inventory system.

## User Stories

### Story 1: Network Anomaly Awareness

As a NetBar user, I want the app to point out unusual network behavior so I can quickly understand whether an app, VPN, or connection issue needs attention.

Acceptance criteria:

1. WHEN total network speed remains above the configured high-traffic threshold for the configured duration THEN NetBar SHALL create a high-traffic anomaly event.
2. WHEN an application dominates app-level traffic above the configured spike threshold THEN NetBar SHALL create an application-spike anomaly event.
3. WHEN network traffic drops from an active baseline to near-idle for the configured duration THEN NetBar SHALL create a network-drop anomaly event.
4. WHEN traffic resumes after a network-drop state THEN NetBar SHALL create a network-recovered anomaly event.
5. WHEN interface traffic significantly exceeds app-attributed traffic and a proxy/VPN candidate exists THEN NetBar SHALL create a proxy-attribution anomaly event.
6. WHEN an anomaly is detected within its cooldown window THEN NetBar SHALL suppress duplicate user-facing notifications while retaining internal state.

### Story 2: Today and 7-Day History

As a NetBar user, I want a lightweight local summary of today's traffic and recent days so I can understand my usage trend without opening another monitor.

Acceptance criteria:

1. WHEN NetBar samples interface traffic THEN NetBar SHALL update today's estimated download and upload totals using positive byte deltas.
2. WHEN NetBar samples app traffic THEN NetBar SHALL update today's estimated per-application totals using current rates and sample interval.
3. WHEN the local date changes THEN NetBar SHALL archive the completed day and start a new daily summary.
4. WHILE storing daily history NetBar SHALL retain at most 7 completed day summaries plus the current day summary.
5. WHERE historical values are displayed, NetBar SHALL label them as estimates rather than exact billing-grade measurements.

### Story 3: Clear Application Top

As a NetBar user, I want to see both the app using traffic right now and the app that used the most traffic today.

Acceptance criteria:

1. WHEN the details window has app traffic data THEN NetBar SHALL show a realtime Top section using current app rates.
2. WHEN today's app usage has cumulative data THEN NetBar SHALL show a Today Top section using stored estimated totals.
3. WHEN an app is classified as proxy, helper, or system THEN NetBar SHALL show a role label in Top rows.
4. WHEN app data is unavailable THEN NetBar SHALL show an empty state explaining that Top data needs app traffic sampling.

### Story 4: Notification Onboarding

As a NetBar user, I want notification permission to be requested with context, not unexpectedly.

Acceptance criteria:

1. WHEN v0.38.0 launches and the user has not seen notification onboarding THEN NetBar SHALL show an in-app notification onboarding card.
2. WHEN the user chooses to enable anomaly notifications THEN NetBar SHALL request macOS notification authorization.
3. IF notification authorization is granted THEN NetBar SHALL enable system notifications according to user preferences.
4. IF notification authorization is denied THEN NetBar SHALL keep app-internal anomaly cards and pet cues active.
5. WHEN the user dismisses onboarding THEN NetBar SHALL not show it again unless preferences are reset.

### Story 5: Menu Bar Presets

As a NetBar user, I want one-click menu bar presets so I can quickly switch between compact, traffic-focused, and pet-focused layouts.

Acceptance criteria:

1. WHEN the user selects a built-in preset THEN NetBar SHALL apply the preset to `StatusBarSettings` immediately.
2. WHEN the user manually changes a menu bar setting after applying a preset THEN NetBar SHALL show the current preset state as custom.
3. WHEN a preset is applied THEN NetBar SHALL preserve unrelated preferences such as language, Dock visibility, and app list filters.
4. WHEN v0.38.0 ships THEN NetBar SHALL include only built-in presets, not user-saved custom presets.

### Story 6: Lightweight Pet Intelligence

As a NetBar user who enables the pet feature, I want the pet to explain important network events while still feeling lightweight and optional.

Acceptance criteria:

1. WHEN an anomaly event is generated and the pet is enabled THEN the pet SHALL emit a concise cue explaining the event.
2. WHEN an application-spike event includes an application name THEN the pet cue SHALL mention that application.
3. WHEN a proxy-attribution event occurs THEN the pet cue SHALL explain that traffic may be concentrated in a proxy/VPN process.
4. WHILE no anomaly is active THEN the pet SHALL retain existing lightweight reminders and interactions.
5. WHEN the user selects the pet menu bar preset THEN NetBar SHALL make the character more prominent without changing the selected character.

## Architecture

### New Modules

#### `NetworkHistoryStore`

Responsibilities:

- Persist today's summary and the most recent 7 completed daily summaries.
- Update daily interface totals from positive byte deltas.
- Update daily application totals from sampled app rates and sample intervals.
- Handle date rollover.
- Expose summaries for details-window presentation.

Storage:

- JSON file under the app support directory for history data.
- UserDefaults for small preference flags and switches.

Rationale:

- History data can grow beyond a comfortable UserDefaults payload.
- JSON keeps the implementation dependency-free and easy to inspect in tests.

#### `NetworkAnomalyDetector`

Responsibilities:

- Convert `NetworkSnapshot`, `ApplicationTrafficState`, history summaries, and intelligence settings into `[NetworkAnomalyEvent]`.
- Maintain enough internal state for sustained thresholds, drop/recovery state, and cooldown keys.
- Avoid UI, notification, or persistence side effects.

The detector is pure model logic from the perspective of UI and notification layers.

#### `NetworkNotificationController`

Responsibilities:

- Manage notification authorization state.
- Send macOS notifications for anomaly events.
- Enforce global and per-kind notification toggles.
- Enforce notification cooldowns.
- Degrade cleanly to in-app-only behavior when authorization is denied.

#### `NetworkIntelligenceSummary`

Responsibilities:

- Aggregate the current anomaly status, today summary, 7-day summaries, realtime Top, and today Top into a UI-friendly model.
- Keep `NetworkPopoverView` from recomputing business rules inline.

#### `MenuBarPreset`

Responsibilities:

- Define built-in menu bar presets.
- Apply a preset to `StatusBarSettings`.
- Report whether current settings still match a preset or are custom.

### Existing Module Changes

#### `NetworkMonitor`

`NetworkMonitor` remains the sampling coordinator. It should not become the main business-logic container.

Allowed additions:

- Publish or expose a `NetworkIntelligenceSummary`.
- Forward snapshot and app traffic updates into history and detector components.
- Trigger notification and pet observers through small coordinator methods.

Avoid:

- Embedding anomaly rules directly in `NetworkMonitor`.
- Embedding history JSON serialization directly in `NetworkMonitor`.
- Adding view-specific formatting logic.

#### `NetworkPopoverView`

Add presentation sections, but keep rules in model/presentation helpers:

- Anomaly status card.
- Today summary.
- Realtime/Today Top app section.
- 7-day collapsible summary.

#### `AppPreferences`

Add intelligence-related preferences:

- `hasSeenNotificationOnboarding`
- `isAnomalyDetectionEnabled`
- `isSystemNotificationEnabled`
- `highTrafficThreshold`
- `isApplicationSpikeAlertEnabled`
- `isNetworkDropAlertEnabled`
- `isProxyAttributionAlertEnabled`
- `isHistoryTrackingEnabled`

#### `PetController`

Add a method that accepts `NetworkAnomalyEvent` and emits a pet cue when appropriate.

## Data Model

### `NetworkDailySummary`

Fields:

- `dateKey: String`
- `downloadBytes: UInt64`
- `uploadBytes: UInt64`
- `peakDownloadBytesPerSecond: Double`
- `peakUploadBytesPerSecond: Double`
- `sampleCount: Int`
- `activeSeconds: TimeInterval`
- `topApplications: [ApplicationDailyUsage]`

### `ApplicationDailyUsage`

Fields:

- `applicationID: String`
- `displayName: String`
- `processNames: [String]`
- `downloadBytes: UInt64`
- `uploadBytes: UInt64`
- `lastSeenAt: Date`
- `role: ApplicationAttributionRole`

### `NetworkAnomalyEvent`

Fields:

- `id: UUID`
- `kind: NetworkAnomalyKind`
- `severity: NetworkAnomalySeverity`
- `title: String`
- `message: String`
- `timestamp: Date`
- `applicationName: String?`
- `bytesPerSecond: Double?`
- `cooldownKey: String`

### `NetworkAnomalyKind`

Cases:

- `highTraffic`
- `applicationSpike`
- `networkDrop`
- `networkRecovered`
- `proxyAttributionGap`

### `NetworkAnomalySeverity`

Cases:

- `info`
- `warning`
- `critical`

## Anomaly Rules

### High Traffic

Default rule:

- Total speed is above 10 MB/s for 10 consecutive seconds.
- Cooldown is 10 minutes.

User-facing output:

- Title: high traffic detected.
- Message includes total speed and Top app when available.

### Application Spike

Default rule:

- App current total speed exceeds 5 MB/s.
- App accounts for at least 60% of app-level traffic.
- Condition persists for 5 seconds.
- Cooldown is 10 minutes per application.

User-facing output:

- Message includes app name, speed, and share.

### Network Drop

Default rule:

- Recent total speed is below 1 KB/s.
- Previous 30-second average was above 100 KB/s.
- Condition persists for 8 seconds.
- Cooldown is 3 minutes.

User-facing output:

- App card and optional notification say the network appears idle or disconnected.

### Network Recovered

Default rule:

- Detector is in a dropped state.
- Total speed exceeds 20 KB/s for 3 consecutive seconds.
- Cooldown is 3 minutes.

User-facing output:

- Informational event showing recovery.

### Proxy/VPN Attribution Gap

Default rule:

- Interface total speed is at least 1 MB/s.
- Application attribution coverage is below 40%.
- App traffic includes at least one proxy/VPN candidate.
- Cooldown is 15 minutes.

User-facing output:

- Message explains that traffic may be concentrated in the proxy/VPN process.

## Details Window Design

The details window remains a single scrollable tool surface with dense cards.

Recommended order:

1. Header with live speeds.
2. Anomaly status card.
3. Today summary.
4. Existing traffic trend chart.
5. Application Top section.
6. Existing application traffic details.
7. Existing interface details.

### Anomaly Status Card

States:

- Normal: green, "Network status normal".
- Attention: yellow/orange, latest warning event.
- Critical: orange/red, network drop or sustained high traffic.

Content:

- Event title.
- Time.
- Short explanation.
- Related application when available.
- Small action to view Top apps or open Intelligence preferences.

### Today Summary

Cards:

- Today download estimate.
- Today upload estimate.
- Today peak speed.
- Active time.

Empty state:

- Explain that statistics appear after NetBar has run for a few minutes.

### Application Top Section

Segmented mode:

- Realtime.
- Today.

Realtime Top:

- Top 3 apps by current app-level traffic.
- Show app name, role label, download/upload, and share.

Today Top:

- Top 5 apps by estimated daily traffic.
- Show app name, total bytes, and last seen time.

### 7-Day Summary

Use a collapsible section:

- Default collapsed.
- Header shows 7-day total download/upload.
- Expanded rows show date, download/upload, peak, and top app.

## Preferences Design

Add a new Preferences tab: `智能` / `Intelligence`.

Sections:

### Notification Onboarding

Shown when `hasSeenNotificationOnboarding == false`.

Actions:

- Enable anomaly notifications.
- Not now.

### Anomaly Detection

Controls:

- Anomaly detection on/off.
- High traffic threshold: 5 / 10 / 25 / 50 MB/s.
- Application spike alerts on/off.
- Network drop/recovery alerts on/off.
- Proxy/VPN attribution alerts on/off.

### System Notifications

Controls:

- System notifications on/off.
- Authorization status: authorized, denied, not determined.
- Button to request authorization when not determined.

### History

Controls:

- Track today and last 7 days on/off.
- Clear history data.
- Short explanation that values are estimates.

## Menu Bar Presets

Built-in presets:

1. Minimal
   - Compact, low visual noise.
   - Single prominent speed value.
2. Up/Down
   - Existing default two-line traffic style.
3. Total Traffic
   - Single-line total speed.
4. App Focus
   - Keeps menu bar calm and emphasizes Top apps in the details window.
5. Pet Mode
   - Makes the selected character more prominent.
   - Uses automatic composite or network speed for animation speed.

Behavior:

- Preset selection immediately applies to `StatusBarSettings`.
- Manual menu bar edits after preset application mark current preset as custom.
- v0.38.0 does not support saving custom presets.

## Notification Flow

1. Detector emits `NetworkAnomalyEvent`.
2. Coordinator stores the event in current intelligence summary.
3. Details window shows the event in the anomaly card.
4. Pet controller receives the event if pet is enabled.
5. Notification controller checks settings, authorization, and cooldown.
6. If allowed, notification controller sends a macOS notification.

If authorization is denied:

- Details window still shows anomaly cards.
- Pet cues still work.
- Preferences show denied status.
- System notification toggle remains disabled or explains how to re-enable in System Settings.

## Pet and Character Linkage

Pet cues by event:

- High traffic: mention total speed and Top app if known.
- Application spike: mention app name, share, and speed.
- Network drop: short cue that network activity has gone quiet.
- Network recovered: short cue that network activity is back.
- Proxy/VPN attribution gap: explain that traffic may be concentrated in a proxy/VPN process.

Pet mood:

- High activity today: excited.
- Normal traffic: happy.
- Long idle period: sleepy.

Pet Mode preset:

- Does not change the selected character.
- Makes character display more prominent.
- Keeps controls reversible by changing preset or manual settings.

## Error Handling and Degradation

- If history JSON cannot be read, NetBar starts a fresh history file and keeps sampling.
- If history JSON cannot be written, NetBar keeps in-memory summaries for the session and exposes a non-blocking warning in diagnostics or logs.
- If app traffic is unavailable, realtime app Top shows an explanatory empty state.
- If notifications are denied, anomaly cards and pet cues continue.
- If system time changes or date rollover is ambiguous, history store uses the current local date key at write time and keeps at most 7 completed day summaries.

## Testing Plan

### Unit Tests

- `NetworkHistoryStore` updates daily totals from positive deltas.
- `NetworkHistoryStore` rolls over dates and retains at most 7 completed summaries.
- App daily usage accumulates and sorts Top apps correctly.
- High traffic detection respects threshold, duration, and cooldown.
- Application spike detection respects app share, duration, and per-app cooldown.
- Network drop and recovery state transitions are stable.
- Proxy/VPN attribution gap requires low coverage and proxy candidate.
- Notification controller suppresses events during cooldown.
- Notification authorization denied state does not disable anomaly cards.
- Menu bar presets apply expected `StatusBarSettings`.
- Manual status bar edits mark current preset state as custom.
- Pet cue generation includes relevant app names for app spike events.

### Integration Tests

- Network monitor update path feeds history and detector without blocking sampling.
- Details presentation summary reflects current anomaly and daily history.
- Preferences persist intelligence settings and notification onboarding state.

### Manual Verification

- First v0.38 launch shows notification onboarding.
- Enabling notification requests macOS authorization with context.
- Details window remains readable at the current 440px width.
- App Top empty states are understandable before app traffic samples arrive.
- Built-in presets can be applied and manually overridden.
- `swift test` passes.
- `./Scripts/build-app.sh` passes.
- `./Scripts/package-release.sh` produces release zip and sha256.

## Release Plan

Target version: `v0.38.0`.

Implementation phases:

1. Data layer:
   - Add history store.
   - Add anomaly detector.
   - Add intelligence settings and summary models.
2. Experience layer:
   - Add Intelligence preferences tab.
   - Add details window sections.
   - Add notification onboarding and controller.
   - Add menu bar presets.
3. Differentiation and release:
   - Add pet cues and pet mode linkage.
   - Update README and CHANGELOG.
   - Upgrade `Info.plist`.
   - Run full verification.
   - Package and publish release.

## Open Decisions Resolved

- Scope: large combined release.
- Notification strategy: first-run v0.38 onboarding before permission request.
- History retention: today plus recent 7-day summaries.
- Application Top: realtime Top and today's cumulative Top.
- Menu bar presets: built-in presets only.
- Pet enhancement style: lightweight practical and friendly cues.

