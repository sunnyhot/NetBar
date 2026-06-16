# NetBar Performance Optimization Design

## Goal

Reduce NetBar's runtime overhead across the full hot path while preserving existing user-visible behavior. The optimization should target background CPU and power usage, disk I/O from history persistence, status bar rendering cost, and detail-window responsiveness.

## Success Criteria

- Background mode avoids unnecessary `nettop`, `ps`, Mach metric reads, JSON writes, and full status item redraws.
- Opening the traffic detail window still shows fresh app traffic and system resource data without stale-state surprises.
- RunCat and dynamic color rendering remain visually identical, but repeated layout, tinting, and whole-image rendering are reused where possible.
- History and intelligence summaries remain current in memory, while disk persistence is batched safely.
- The work remains verifiable with unit tests plus `swift test` and `./Scripts/build-app.sh`.

## Chosen Approach

Use a staged aggressive optimization that touches both runtime hot paths:

1. Rework sampling and history persistence first.
2. Rework status bar render caching second.
3. Move detail-window derived data into testable presentation caches third.

This is more ambitious than isolated micro-optimizations, but it keeps each stage independently testable and reversible.

## Architecture

### Performance Sampling Coordinator

Add a small coordinator responsible for selecting sampling policies from app state:

- Detail window visibility.
- Screen lock state.
- Low Power Mode.
- Network activity level.
- Whether status bar animation needs system metrics.

`NetworkMonitor` should continue owning network snapshots and app traffic state, but timer decisions should move out of scattered call sites. The coordinator should expose simple policy values such as interface interval, system resource interval, app traffic enabled, and animation metric enabled.

The coordinator must be idempotent. Repeated open, close, lock, unlock, and power-mode transitions must not create duplicate timers or leave a sampler stuck in a refreshing state.

### Shared System Metrics

Today, system metrics are sampled in more than one place: `NetworkMonitor.refreshSystemResources()` for detail data and `SystemMetricsSampler` for status bar animation speed. Replace this with a shared system metrics source owned by `NetworkMonitor`; status bar animation speed should consume the latest published `systemResources` snapshot instead of starting a parallel metrics timer.

The design goal is one live sample per policy interval. Status bar animation speed, detail resource cards, and app traffic resource summaries should reuse the same recent snapshot whenever possible.

### Batched History Persistence

Keep `NetworkHistoryStore.record(...)` synchronous for in-memory state so UI and intelligence summaries update immediately. Change disk writes to dirty-state batching:

- Mark the store dirty after record/configuration changes.
- Schedule a delayed save with a 20-second default debounce.
- Coalesce multiple snapshot records into one write.
- Add `flushNow()` for lifecycle points that require durability.

Mandatory flush points:

- App termination.
- Screen lock or monitor stop.
- Clearing history.
- Rollover to a new day.
- Before replacing or reconfiguring history storage.

Existing `storageStatus` behavior should stay intact. Write failures should still publish `.writeFailed(...)` without crashing the app.

### Status Bar Render Cache

Keep `StatusBarDisplayRenderer` as the CoreGraphics renderer, but split cache responsibility into clearer layers:

- Text layout cache: keyed by display strings, font settings, arrows, ordering, alignment, and smart context.
- Character frame cache: keyed by character id, frame index, scale, facing, head swing, custom revision, and color mode bucket.
- Final image cache: keyed by the full `StatusBarRenderSignature`, with a bounded count.

The render controller should avoid full-image rendering when only non-visible model state changes. Dynamic color modes should keep using quantized time buckets so color refreshes are decoupled from mouse tracking and network sample frequency.

### Detail Presentation Cache

Move these derived values out of SwiftUI `body` paths:

- Visible application list after system-process filtering and search.
- Sorted application list for each sort mode.
- Summary metrics for app traffic display modes.
- History-window aggregate metrics.

This can live in existing presentation types such as `ApplicationTrafficPresentation` and `NetworkHistoryPresentation`, or in small cache structs if stateful caching is needed. The UI should still consume simple values and keep the current look and localization behavior.

## Data Flow

```text
App/Window/Power state
  -> PerformanceSamplingCoordinator
       -> NetworkMonitor timers and app traffic policy
       -> Shared system metric source
       -> Status bar animation metric policy

getifaddrs / nettop / ps / Mach APIs
  -> reader protocols
  -> NetworkMonitor published state
  -> in-memory history and intelligence summary
  -> delayed NetworkHistoryStore disk flush

published display state
  -> presentation/cache layer
  -> StatusBarDisplayRenderer or SwiftUI views
```

In memory, data should remain responsive. Expensive side effects should be coalesced.

## Error Handling

- `nettop` failures continue to surface through `ApplicationTrafficState.errorMessage` while preserving existing displayed data where appropriate.
- A stopped or hidden detail window must stop application traffic sampling and terminate the streaming reader.
- Delayed history saves must not lose data during lifecycle transitions because `flushNow()` is called at mandatory flush points.
- Failed disk writes should keep the current `NetworkHistoryStorageStatus` behavior.
- Shared metrics failures should degrade to existing empty or zero values rather than blocking network sampling or rendering.
- Cache misses should fall back to normal rendering and should never change visual output.

## Testing

Add XCTest coverage for:

- Sampling policy transitions for background, detail-visible, Low Power Mode, and screen-locked states.
- No duplicate timers or duplicate sampler starts across repeated transitions.
- History store batching: many `record(snapshot:)` calls schedule one delayed save, while `flushNow()` writes immediately.
- History flush behavior for clear, stop, lock, and rollover paths.
- Shared system metrics: status bar animation and detail resources can use one source without starting parallel metric loops.
- Render cache behavior: identical signatures skip redraw, text layout is reused, and character cache keys invalidate on frame/color/revision changes.
- Detail presentation behavior: filtering, search, sorting, and summary metrics match existing expectations.

Full verification remains:

```bash
swift test
./Scripts/build-app.sh
```

## Scope Boundaries

This pass should not redesign the UI, change attribution rules, add dependencies, replace `nettop`, change sandbox assumptions, or alter RunCat assets. It may introduce small helper types and focused tests where they clarify the new performance boundaries.

## Rollout Plan

1. Implement sampling-policy and history-persistence changes with tests.
2. Implement shared system metrics and remove redundant sampler work.
3. Implement status bar render cache layering with renderer tests.
4. Implement detail presentation caches and verify existing presentation behavior.
5. Run full tests and release build.
