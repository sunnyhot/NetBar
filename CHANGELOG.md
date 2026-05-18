# Changelog

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
