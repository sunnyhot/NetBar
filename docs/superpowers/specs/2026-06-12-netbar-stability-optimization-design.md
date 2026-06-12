# NetBar Stability Optimization Design

## Goal

Improve NetBar's release safety, macOS 13 compatibility, runtime sampling consistency, and release build quality without broad UI rewrites.

## Scope

This optimization covers five focused areas:

1. Update archive integrity: preserve `sha256` from `latest.json`, compute the downloaded archive hash, and block install on mismatch.
2. Swift concurrency compatibility: remove build warnings around `NSImage` crossing task boundaries and MainActor-isolated state mutation.
3. Sampling scheduler consistency: keep `NetworkMonitor` app-traffic sampling disabled while the details window is hidden, including after power-save timer rescheduling.
4. Release signing gate: make release builds fail when signing fails, while keeping an explicit unsigned escape hatch for local use.
5. Small warning cleanup: remove unused code that appears in release builds.

## Architecture

The update work adds checksum metadata to `GitHubReleaseAsset` and a small archive-integrity helper. `AppUpdater` will validate the zip before unzip/installation; GitHub API fallback assets simply skip checksum validation when no checksum is available.

The sampling work keeps all timer creation inside purpose-specific scheduling methods. `setPowerSaveMode(_:)` reschedules network/resource timers and only recreates the application traffic timer when `shouldSampleApplicationTraffic` is true.

The concurrency work keeps AppKit objects on a safe path by processing custom character frames sequentially rather than passing `NSImage` through task groups on macOS 13. `SystemPowerObserver` will use the same `Task { @MainActor in ... }` pattern for all notification callbacks.

## Testing

Add XCTest coverage for:

- Manifest-based release fetch preserves SHA-256 on the release asset.
- Archive checksum validation accepts matching hashes and rejects mismatches.
- Power-save rescheduling does not start app traffic reads while the traffic detail window is hidden.

Existing full verification remains:

- `swift test`
- `./Scripts/build-app.sh`

## Out Of Scope

This pass does not redesign the preferences UI, split large rendering files, add notarization automation, or change the nettop attribution model. Those are useful follow-ups but would broaden this optimization beyond the stability fixes requested here.
