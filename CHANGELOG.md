# Changelog

## v0.33.0 (2026-05-20)

### Performance — Cache & Power Optimization

Targeted caching and power-management optimizations to reduce CPU, energy, and IPC overhead.

- **Display name cache** — Cache `NSRunningApplication` display name lookups by PID, eliminating repeated system IPC calls on every 5-second nettop sampling cycle
- **System process classification cache** — Cache `isLikelySystemProcess()` results by application ID, avoiding repeated string normalization and set lookups on every SwiftUI layout pass
- **App icon cache** — Cache resolved application icons by PID, preventing repeated disk I/O and IPC from SwiftUI view body evaluations when the popover is visible
- **Screen lock full stop** — Stop all network monitoring timers and nettop processes when the screen is locked; resume automatically on wake for zero CPU/energy footprint during lock


## v0.32.0 (2026-05-19)

### Battery Optimization — Adaptive Power Management

Comprehensive battery optimization: adaptive sampling, animation frame rate scaling, system state awareness, and on-demand nettop.

- **[LUC-121] Adaptive sampling interval** — NetworkMonitor dynamically adjusts sampling frequency: idle → 3s, low traffic → 2s, high traffic → 1s; power-save mode doubles all intervals
- **[LUC-123] Adaptive animation frame rate** — RunCat animation scales FPS based on network activity: idle → static/0.5fps, active → full FPS; GooglyEyes mouse dedup + distance-based frequency switching
- **[LUC-126] System state awareness** — Low Power Mode detection + screen lock monitoring; auto-pauses animation and reduces sampling when screen is locked or battery is low
- **[LUC-128] Render coalesce optimization** — StatusBarController render coalesce strategy improved to reduce unnecessary redraws
- **[LUC-129] nettop on-demand sampling** — Application traffic sampling pauses/resumes on demand; nettop process stops when not needed
- **[LUC-131] nettop visibility integration** — nettop process auto-starts when traffic detail window opens and stops when it closes, via `isApplicationTrafficVisible` property
- **[LUC-133] GooglyEyes smart refresh** — Mouse position dedup (< 1pt threshold) + distance-based frequency scaling (near → 15fps, far → 3fps)
- **[LUC-134] PetController write reduction** — Dirty flag + batch save reduces UserDefaults write frequency for pet state

Expected improvement: ~70% CPU wake reduction during idle; zero extra power consumption when screen locked or low power mode.

## v0.31.0 (2026-05-19)

### Performance — Long-running Energy Optimization

Fixes high energy consumption and device overheating during extended use.

- **[LUC-108] StreamingNettopReader incremental parsing** — Replaced full-string O(n) parse with incremental line-by-line parsing, eliminating CPU/memory growth over time
- **[LUC-109] Render throttling + FPS cap** — Capped status bar rendering at 10fps; added render coalescing to merge rapid state changes into single draw calls
- **[LUC-110] Rendered image cache** — Added LRU cache (12 entries) for rendered status bar images, reusing bitmap output for repeated animation frames
- **[LUC-112] Gradient tint cache** — Added caching for `tintImageGradient()` results, avoiding repeated NSBitmapImageRep + gradient + alpha mask creation per frame
- **[LUC-113] Combine deduplication + debounce** — Added `removeDuplicates()` on snapshot stream; debounced settings/custom character changes at 100ms to suppress redundant re-renders
- **[LUC-114] GooglyEyes throttle 30fps→15fps** — Reduced GooglyEyes timer from 30fps to 15fps; added automatic pause when app moves to background

## v0.30.2 (2026-05-19)

### Bug Fixes

- **[LUC-105] Fix startup crash in Dictionary.merge** — Updated `NetworkMonitor` to use `uniquingKeysWith` to handle duplicate keys safely without throwing assertion failures.
- **[LUC-106] Optimize ApplicationTrafficReader.parse()** — Added deduplication using `id` in `StreamingNettopReader` to ensure robust dictionary initialization.

## v0.30.1 (2026-05-18)

### Bug Fixes

- **[LUC-104] Fix auto-update download validation** — Fixed validation to properly skip older builds from GitHub releases.

## v0.30.0 (2026-05-19)

### Performance — Comprehensive Optimization Round

- **[LUC-99] Async network refresh + primary interface cache** — Moved `getifaddrs()` + `SCDynamicStore` reads off main thread to `Task.detached`; cached primary interface name to avoid redundant system calls every second
- **[LUC-100] Persistent nettop process** — Replaced per-sample `fork+exec` of `/usr/bin/nettop` (every 5 seconds) with a single persistent process, eliminating ~720 process spawns per hour
- **[LUC-101] Formatters cache + ring buffer** — Cached `NumberFormatter` instances; replaced `Array.removeFirst()` O(n) with O(1) ring buffer for 90-second network history
- **[LUC-103] Async custom character image processing** — Offloaded image resize/color processing to background queue with persistent disk cache
- **[LUC-95] NSCache for character/tint images** — Added in-memory image cache for animation frame reads and tint bitmap operations, eliminating repeated disk I/O and per-frame bitmap creation at 24 FPS
- **[LUC-97] Dynamic color pipeline decoupling** — Reduced dynamic color update rate from 20 Hz to 4 Hz; decoupled color and position pipelines to prevent redundant full re-renders

## v0.29.4 (2026-05-18)

## v0.29.4 (2026-05-18)

### Performance

- **Settings menu bar tab optimization** — Eliminated lag in the Preferences → Menu Bar tab:
  - Isolated 8 FPS animation timer into dedicated sub-views (`AnimatedPreviewSection`, `AnimatedCharacterCatalog`) to prevent full `MenuBarPreferencesView` re-render on every frame tick
  - Added `NSCache` for character preview icons, eliminating repeated disk I/O per frame (previously 27 × disk reads per tick)
  - Replaced per-character `String.split` + `map` + `contains` in rotation pool with `Set<String>` lookup (O(n) → O(1) per check)

- Related issues: LUC-91, LUC-92, LUC-93

## v0.29.3 (2026-05-18)

- Fix: restore Pet system, RunCat resources, and tests from v0.28.9
- Fix: add entitlements and Gatekeeper workaround docs

## v0.29.2 (2026-05-18)

- Fix: ensure appearance mode immediately applies to all UI surfaces

## v0.29.1 (2026-05-17)

- Fix: optimize appearance mode switching to eliminate lag

## v0.29.0 (2026-05-17)

- Initial tracked release
