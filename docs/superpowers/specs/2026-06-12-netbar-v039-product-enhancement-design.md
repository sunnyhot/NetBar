# NetBar v0.39 Product Enhancement Design

## Overview

v0.39 is a broad product enhancement release. It upgrades five visible product pillars in parallel:

1. Network insights.
2. Menu bar experience.
3. Local history statistics.
4. Release health and diagnostics.
5. Pet and character feedback.

The release is intentionally broader than the v0.38 network-intelligence release, but each pillar has a bounded first layer of value. The goal is for users to feel that NetBar has become more capable across the whole product without changing its core promise:

- Local-first macOS menu bar network monitoring.
- No packet capture.
- No network content inspection.
- No administrator permission requirement.
- Pure Swift and system frameworks only.
- macOS 13+.
- Bilingual Chinese and English UI.

## Goals

- Show a readable local insight stream that explains recent network anomalies and possible causes.
- Add a smart menu bar mode that can highlight the most relevant live status without removing manual presets.
- Extend local history into a 30-day estimated traffic ledger with peaks and application ranking.
- Add a diagnostics and health surface for update status, sampling state, permissions, and support summaries.
- Make the pet and character system react to network state, daily activity, and anomaly events while staying lightweight.

## Non-Goals

- No packet capture, protocol inspection, or traffic content analysis.
- No firewall, blocking, throttling, or per-application network control.
- No cloud sync, account system, telemetry, or remote analytics.
- No external dependencies.
- No billing-grade traffic accounting.
- No complex pet economy, inventory, shop, or cloud progression.
- No large renderer rewrite of `StatusBarStyle.swift`.
- No migration to a different UI framework or project structure.

## Product Scope

### Pillar 1: Network Insight Stream

The details window gains a user-readable insight stream. It converts anomaly events and attribution context into concise cards with:

- Event title.
- Time.
- Severity.
- Short explanation.
- Optional application name.
- Likely cause.
- Suggested local action.

Existing anomaly detection remains local and rule-based. The insight stream does not read packets or network payloads.

### Pillar 2: Smart Menu Bar Mode

Preferences gain an optional smart menu bar mode. When enabled, NetBar selects the most useful menu bar emphasis based on current context:

- Normal traffic: use the user's current manual display configuration.
- High total traffic: emphasize total throughput.
- Upload-dominant activity: emphasize upload.
- Active anomaly: show a lightweight status marker.
- Dominant application: show a safe shortened application label when there is room.

Manual presets and existing menu bar customization remain available. Disabling smart mode restores the user's manual configuration.

### Pillar 3: 30-Day Local Traffic Ledger

The history model expands from short-term and 7-day summaries to a 30-day estimated ledger:

- Today summary.
- Last 7 days summary.
- Last 30 days summary.
- Peak download and upload records.
- Realtime Top applications.
- 30-day application ranking when application traffic sampling is available.

All traffic totals are labeled as estimates.

### Pillar 4: Diagnostics and Health

Preferences gain a diagnostics and health area that helps users and maintainers understand the app state without exposing network content:

- App version and build.
- Bundle identifier.
- Update source and last update-check result.
- Archive checksum support status when available.
- Sampling status for interface, application traffic, system resources, and history.
- Notification authorization state.
- History file status.
- Power-save state.
- Copyable plain-text diagnostics summary.

### Pillar 5: Pet and Character Feedback

The pet and character system gains lightweight feedback connected to product state:

- Mood based on current network state.
- Activity level based on today's estimated traffic or animation playback.
- Short event feedback when an insight event occurs.
- Continued support for existing cumulative character playback statistics and milestone effects.

If the pet feature is disabled, all network insights and history features continue to work normally.

## User Stories and Acceptance Criteria

### Story 1: Network Insight Stream

As a NetBar user, I want recent network events to be explained in plain language so I can understand what happened without reading raw counters.

Priority: High
Complexity: Medium
Dependencies: `NetworkAnomalyDetector`, `NetworkIntelligenceSummary`, application attribution roles, details window.

Acceptance criteria:

1. WHEN a supported anomaly event is detected THEN NetBar SHALL add an insight card with title, timestamp, severity, explanation, and suggested action.
2. WHEN duplicate events of the same type occur during their cooldown window THEN NetBar SHALL merge or suppress repetitive cards in the user-facing stream.
3. IF an event has no application name THEN NetBar SHALL show a generic explanation without empty fields.
4. IF application attribution is unavailable because `nettop` failed or is paused THEN NetBar SHALL keep interface-level insights available.
5. WHERE insight text is user-visible NetBar SHALL provide Chinese and English copy.

### Story 2: Smart Menu Bar Mode

As a NetBar user, I want the menu bar to highlight what matters right now so I can understand the current network state at a glance.

Priority: High
Complexity: Medium
Dependencies: `StatusBarSettings`, `StatusBarController`, `StatusBarDisplayRenderer`, anomaly events, current network snapshot.

Acceptance criteria:

1. WHEN smart menu bar mode is enabled AND a high-priority network state exists THEN NetBar SHALL choose the matching display emphasis.
2. WHEN smart menu bar mode is disabled THEN NetBar SHALL render using the user's manual status bar settings.
3. IF a dominant application name is too long for the configured width THEN NetBar SHALL shorten it without expanding beyond safe menu bar bounds.
4. WHEN the computed smart context has not changed THEN NetBar SHALL continue to avoid redundant redraws through the render signature path.
5. IF smart context evaluation fails or lacks data THEN NetBar SHALL fall back to the user's manual display configuration.

### Story 3: 30-Day Local Traffic Ledger

As a NetBar user, I want a local estimate of recent traffic and top applications so I can understand usage trends over time.

Priority: High
Complexity: Medium
Dependencies: `NetworkHistoryStore`, application traffic sampling, date rollover handling, details window presentation.

Acceptance criteria:

1. WHEN the local date changes THEN NetBar SHALL archive the completed day and start a new current-day summary.
2. WHILE history tracking is enabled NetBar SHALL retain up to 30 completed daily summaries plus the current day summary.
3. WHEN interface byte counters increase THEN NetBar SHALL update estimated download and upload totals using positive deltas only.
4. WHEN application traffic samples are available THEN NetBar SHALL update application-level estimated totals and rankings.
5. IF history data is empty THEN NetBar SHALL show an empty state that explains that the ledger is built from local samples.
6. WHERE history totals are displayed NetBar SHALL label them as estimates.
7. WHEN history tracking is disabled THEN NetBar SHALL stop writing new history samples.

### Story 4: Diagnostics and Health

As a NetBar user or maintainer, I want a privacy-safe diagnostics summary so update or sampling problems can be investigated faster.

Priority: Medium
Complexity: Medium
Dependencies: `AppUpdater`, `NetworkMonitor`, notification authorization, history storage, preferences UI.

Acceptance criteria:

1. WHEN the diagnostics area is opened THEN NetBar SHALL show app, update, sampling, permission, history, and power-save health statuses.
2. WHEN the user copies diagnostics THEN NetBar SHALL write a plain-text summary to the macOS pasteboard.
3. IF the last update check failed THEN NetBar SHALL include a short failure reason in the health status.
4. IF history storage is missing or unreadable THEN NetBar SHALL report that state without crashing the preferences window.
5. WHERE diagnostics include filesystem paths NetBar SHALL not include packet contents, visited domains, URLs, chat contents, file contents, or payload data.

### Story 5: Pet and Character Feedback

As a user who enables the pet or character experience, I want it to react to network state in a lightweight way so it feels connected to the app's purpose.

Priority: Medium
Complexity: Medium
Dependencies: `PetController`, `PetState`, anomaly events, daily history, character playback statistics.

Acceptance criteria:

1. WHEN an insight event occurs AND the pet is enabled THEN NetBar SHALL generate a short matching pet cue.
2. WHEN today's activity crosses defined thresholds THEN NetBar SHALL update the pet activity level.
3. IF the pet feature is disabled THEN NetBar SHALL not show pet feedback and SHALL keep network insight behavior unchanged.
4. WHERE character playback statistics exist NetBar SHALL preserve cumulative counts and milestone effects.
5. WHEN no anomaly is active THEN the pet SHALL keep existing idle and lightweight interaction behavior.

## Architecture

### Existing Modules to Keep Stable

`NetworkMonitor` remains the sampling coordinator. It may forward state into new collaborators, but it should not become the home for insight copy, history presentation, status-bar priority logic, diagnostics formatting, or pet mood rules.

`StatusBarStyle.swift` remains the renderer. v0.39 should add model inputs and small rendering branches only where necessary. It should not become a broad product-decision layer.

`NetworkPopoverView` remains a SwiftUI presentation surface. Business rules should live in model or presentation helpers.

### New or Extended Modules

#### `NetworkInsightCenter`

Responsibilities:

- Convert anomaly events, attribution context, history summaries, and current snapshots into insight cards.
- Merge or suppress repetitive user-facing insight cards.
- Generate bilingual text through explicit localized helpers.
- Provide display-ready insight models for `NetworkPopoverView` and pet cues.

Non-responsibilities:

- It does not sample network data.
- It does not send macOS notifications.
- It does not persist long-term history.

#### `StatusBarContextEvaluator`

Responsibilities:

- Evaluate the current network snapshot, anomaly state, application ranking, and user settings.
- Produce a `SmartStatusBarContext`.
- Apply deterministic priority rules for display emphasis.
- Provide a safe fallback to manual display mode.

Non-responsibilities:

- It does not draw the status bar image.
- It does not mutate user preferences.

#### `SmartStatusBarMode`

Responsibilities:

- Define user-facing smart mode options and display emphasis types.
- Preserve manual mode compatibility.
- Support encoding and decoding through `AppPreferences`.

#### `NetworkHistoryPresentation`

Responsibilities:

- Build display-ready history sections for today, 7 days, 30 days, peaks, and application rankings.
- Sort and limit application ranking rows.
- Keep formatting decisions close to presentation while leaving storage in `NetworkHistoryStore`.

#### `DiagnosticsCenter`

Responsibilities:

- Collect app version, bundle, update, sampling, permission, history, and power-save health state.
- Produce privacy-safe diagnostics models.
- Produce a copyable plain-text summary.

Non-responsibilities:

- It does not perform update checks.
- It does not read packet or payload contents.
- It does not upload diagnostics.

#### Pet State Extensions

Responsibilities:

- Add mood and activity level to `PetState`.
- Allow `PetController` to react to insight events.
- Preserve existing play count and milestone behavior.

## Data Flow

```text
System readers
  -> NetworkMonitor
  -> NetworkAnomalyDetector
  -> NetworkInsightCenter
  -> NetworkPopoverView / NetworkNotificationController / PetController

System readers
  -> NetworkMonitor
  -> NetworkHistoryStore
  -> NetworkHistoryPresentation
  -> NetworkPopoverView / DiagnosticsCenter

NetworkMonitor + AppPreferences + NetworkInsightCenter
  -> StatusBarContextEvaluator
  -> StatusBarController
  -> StatusBarDisplayRenderer

AppUpdater + NetworkMonitor + NetworkHistoryStore + AppPreferences
  -> DiagnosticsCenter
  -> Preferences diagnostics view
```

## Preference Changes

Add v0.39 settings through existing `AppPreferences` persistence patterns. All properties should use `didSet { save() }` and `app.`-prefixed keys.

Network insights:

- `isInsightStreamEnabled`
- `insightRetentionLimit`
- `isInsightSuggestionEnabled`

Menu bar:

- `isSmartStatusBarModeEnabled`
- `showsSmartAnomalyMarker`
- `showsSmartTopApplication`

History:

- `historyRetentionDays`
- `isApplicationHistoryRankingEnabled`
- Clear history action in preferences.

Diagnostics:

- Manual refresh action.
- Copy diagnostics action.

Pet and character:

- `isPetMoodFeedbackEnabled`
- `isPetActivityLevelEnabled`

Default behavior should be visible but not noisy:

- Insight stream enabled.
- Smart menu bar mode disabled by default to avoid surprising users who carefully customized the menu bar.
- 30-day history enabled when history tracking is already enabled.
- Diagnostics available without extra setup.
- Pet mood feedback enabled only when pet features are enabled.

## Error Handling and Degradation

- If `nettop` fails, application ranking and application-level insights degrade while interface-level rates continue.
- If history storage cannot be decoded, NetBar backs up the unreadable file and starts a new empty ledger.
- If history storage cannot be written, NetBar reports a diagnostics warning and keeps runtime monitoring active.
- If update checks fail, the failure is recorded in diagnostics instead of interrupting the user.
- If notification authorization is denied, insight cards remain available inside the app.
- If smart menu bar evaluation fails, rendering falls back to manual settings.
- If application names are missing or too long, UI models use safe generic labels or shortened names.
- If the pet feature is disabled, pet feedback is skipped without affecting other systems.

## Testing Strategy

Use the repository's existing XCTest target and keep tests focused on deterministic logic.

### Unit Tests

`NetworkInsightCenter`:

- Creates cards for all supported anomaly kinds.
- Uses fallback copy when optional application data is missing.
- Merges or suppresses duplicate events inside cooldown windows.
- Produces bounded card counts based on retention settings.

`StatusBarContextEvaluator`:

- Prioritizes active anomaly above normal traffic.
- Emphasizes upload when upload dominates.
- Emphasizes total throughput during high traffic.
- Shortens long application names.
- Falls back to manual mode when smart mode is disabled or data is missing.

`NetworkHistoryStore` and `NetworkHistoryPresentation`:

- Retains 30 daily summaries.
- Handles date rollover.
- Ignores negative byte deltas.
- Stops writing when history tracking is disabled.
- Recovers from unreadable storage.
- Sorts application rankings by estimated total bytes.

`DiagnosticsCenter`:

- Produces app, update, sampling, permission, history, and power-save statuses.
- Produces copyable text.
- Excludes packet contents, URLs, domains, and network payload data.
- Handles missing update or history state.

`PetState` and `PetController`:

- Updates mood from insight events.
- Updates activity level from daily activity thresholds.
- Suppresses pet cues when pet feedback is disabled.
- Preserves existing playback statistics.

### Manual Verification

- Run `swift test`.
- Run `./Scripts/build-app.sh`.
- Launch `build/NetBar.app`.
- Open details window and confirm insight/history sections degrade cleanly when app traffic is unavailable.
- Toggle smart menu bar mode and confirm manual settings are restored when disabled.
- Open diagnostics and copy the summary.
- Trigger notification-denied and update-failure states where practical.

## Privacy and Safety

v0.39 does not expand NetBar's data access model. Diagnostics, insights, pet cues, and history are derived from local counters, process names, update status, and app state.

Diagnostics and history must not include:

- Packet contents.
- URLs.
- Domains.
- Webpage contents.
- Chat contents.
- File contents.
- Request or response payloads.

## Implementation Slicing

Even though v0.39 is a broad release, implementation should land in reviewable slices:

1. Models and preferences for v0.39 settings.
2. 30-day history storage and presentation.
3. Network insight stream.
4. Smart menu bar evaluator and rendering integration.
5. Diagnostics center and preferences UI.
6. Pet mood and activity feedback.
7. Integration polish, changelog, and release verification.

Each slice should be testable independently before UI integration expands.

## Open Decisions Resolved for This Spec

- v0.39 is one broad release, not a multi-version roadmap.
- All five pillars are in scope.
- Smart menu bar mode is optional and disabled by default.
- History extends to 30 days, not monthly billing-grade reports.
- Diagnostics are local and copyable only; no upload path is added.
- Pet enhancement is lightweight feedback, not a progression economy.

