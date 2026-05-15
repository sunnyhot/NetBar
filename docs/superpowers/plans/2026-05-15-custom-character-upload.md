# Custom Character Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user-uploaded menu bar characters from static images, GIFs, and frame sequences with configurable pixelation and three generated static-image motion styles.

**Architecture:** Add a focused custom character asset layer beside the built-in RunCat descriptors. The status bar renderer and animation controller resolve a unified asset descriptor so existing menu bar layout and network-speed-based animation remain intact.

**Tech Stack:** Swift 5 mode, AppKit, SwiftUI, Foundation, ImageIO, XCTest, SPM.

---

## File Structure

- Create `Sources/NetBar/CustomCharacter.swift`: custom metadata enums, persisted model, manifest model, and unified `CharacterAsset` descriptor.
- Create `Sources/NetBar/CustomCharacterImageProcessor.swift`: static/GIF/frame sequence decoding, generated motion frames, pixelation, and PNG writing.
- Create `Sources/NetBar/CustomCharacterStore.swift`: Application Support paths, manifest persistence, import/rename/delete/update operations.
- Modify `Sources/NetBar/RunCatAnimation.swift`: let animation work from any asset id and frame count while preserving built-in rotation behavior.
- Modify `Sources/NetBar/StatusBarStyle.swift`: resolve built-in or custom assets, compute custom dimensions, draw custom frame PNGs, and include custom metadata in render signatures.
- Modify `Sources/NetBar/StatusBarController.swift`: own a `CustomCharacterStore`, pass it into rendering, and keep selected ids valid.
- Modify `Sources/NetBar/PreferencesWindowController.swift`: wire store into the preferences view, add import, custom picker, rename/delete, motion, and pixelation controls.
- Modify `Sources/NetBar/AppDelegate.swift`: create and pass one store instance.
- Modify `Tests/NetBarTests/PreferencesAndPresentationTests.swift`: add unit coverage for metadata, store persistence, generated frames, pixelation clamping, fallback, and width calculation.

## Task 1: Custom Character Types

**Files:**
- Create: `Sources/NetBar/CustomCharacter.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests named:
- `testCustomCharacterPixelationScaleClampsToSupportedValues`
- `testCustomCharacterMotionStyleDisplayNamesAreLocalized`
- `testCharacterAssetFallsBackToBuiltInCatForMissingCustomCharacter`

Run: `swift test --filter PreferencesAndPresentationTests/testCustomCharacterPixelationScaleClampsToSupportedValues`
Expected: FAIL because the types do not exist.

- [ ] **Step 2: Implement minimal types**

Define:
- `enum CustomCharacterSourceKind: String, Codable, CaseIterable`
- `enum CustomCharacterMotionStyle: String, Codable, CaseIterable, Identifiable`
- `enum CustomCharacterPixelationScale: Int, Codable, CaseIterable, Identifiable`
- `struct CustomCharacter: Codable, Equatable, Identifiable`
- `struct CharacterAsset: Equatable, Identifiable`

Run: `swift test --filter PreferencesAndPresentationTests/testCustomCharacter`
Expected: PASS for the new type tests.

## Task 2: Image Processor

**Files:**
- Create: `Sources/NetBar/CustomCharacterImageProcessor.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests named:
- `testStaticImageProcessorCreatesSixFramesForEachMotionStyle`
- `testPixelationProcessorReducesInteriorColorVariation`
- `testFrameSequenceImportSortsByLocalizedFilename`

Run: `swift test --filter PreferencesAndPresentationTests/testStaticImageProcessorCreatesSixFramesForEachMotionStyle`
Expected: FAIL because `CustomCharacterImageProcessor` does not exist.

- [ ] **Step 2: Implement processor**

Implement:
- `processedStaticFrames(from:motionStyle:pixelation:)`
- `processedFrameSequence(from:pixelation:)`
- `processedGIFFrames(from:pixelation:maxFrames:)`
- PNG encoding helpers.

Use ImageIO for GIFs and AppKit/CoreGraphics for test-generated images.

Run: `swift test --filter PreferencesAndPresentationTests/testStaticImageProcessorCreatesSixFramesForEachMotionStyle`
Expected: PASS.

Run: `swift test --filter PreferencesAndPresentationTests/testPixelationProcessorReducesInteriorColorVariation`
Expected: PASS.

## Task 3: Store And Manifest Persistence

**Files:**
- Create: `Sources/NetBar/CustomCharacterStore.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests named:
- `testCustomCharacterStorePersistsReloadsRenamesAndDeletesCharacter`
- `testCustomCharacterStoreRegeneratesStaticFramesWhenMotionChanges`
- `testCustomCharacterStoreIgnoresCorruptManifest`

Run: `swift test --filter PreferencesAndPresentationTests/testCustomCharacterStorePersistsReloadsRenamesAndDeletesCharacter`
Expected: FAIL because the store does not exist.

- [ ] **Step 2: Implement store**

Implement Application Support path injection for tests, JSON manifest load/save, static/frame/GIF imports, rename, delete, and static metadata updates.

Run: `swift test --filter PreferencesAndPresentationTests/testCustomCharacterStore`
Expected: PASS for store tests.

## Task 4: Renderer And Animation Integration

**Files:**
- Modify: `Sources/NetBar/RunCatAnimation.swift`
- Modify: `Sources/NetBar/StatusBarStyle.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests named:
- `testCustomCharacterWidthContributesToAutomaticStatusBarWidth`
- `testCustomCharacterRendererDrawsImportedFramePixels`
- `testRunCatAnimationUsesCustomFrameCount`

Run: `swift test --filter PreferencesAndPresentationTests/testCustomCharacterWidthContributesToAutomaticStatusBarWidth`
Expected: FAIL because renderer does not accept custom assets.

- [ ] **Step 2: Implement integration**

Add optional `customCharacterStore` parameters to renderer entry points. Resolve selected ids through `CharacterAsset`, compute custom size, draw custom frame PNGs, and fall back to built-in cat when needed. Update animation to use a lightweight descriptor with id and frame count.

Run: `swift test --filter PreferencesAndPresentationTests/testCustomCharacter`
Expected: PASS for custom renderer and asset tests.

## Task 5: Preferences UI

**Files:**
- Modify: `Sources/NetBar/AppDelegate.swift`
- Modify: `Sources/NetBar/PreferencesWindowController.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests for non-UI helpers**

Add tests named:
- `testImportPanelClassifiesSingleStaticImageVersusFrameSequence`
- `testDeletingSelectedCustomCharacterFallsBackToDefaultCat`

Run: `swift test --filter PreferencesAndPresentationTests/testDeletingSelectedCustomCharacterFallsBackToDefaultCat`
Expected: FAIL because deletion fallback helper does not exist.

- [ ] **Step 2: Implement UI wiring**

Create one `CustomCharacterStore` in `AppDelegate`, pass it to `StatusBarController` and preferences. Add import panel logic, custom picker group, rename/delete controls, and metadata controls for static image motion and pixelation.

Run: `swift test --filter PreferencesAndPresentationTests/testDeletingSelectedCustomCharacterFallsBackToDefaultCat`
Expected: PASS.

## Task 6: Full Verification

**Files:**
- All changed source and tests.

- [ ] **Step 1: Run full tests**

Run: `swift test`
Expected: all XCTest tests pass with 0 failures.

- [ ] **Step 2: Run release app build**

Run: `./Scripts/build-app.sh`
Expected: command exits 0 and prints `build/NetBar.app`.

- [ ] **Step 3: Inspect status**

Run: `git status --short`
Expected: only intentional source, test, docs, and generated build ignored changes.
