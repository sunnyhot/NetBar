# Changelog

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
