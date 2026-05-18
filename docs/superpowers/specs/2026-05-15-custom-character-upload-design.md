# Custom Character Upload Design

Date: 2026-05-15
Project: NetBar

## Goal

NetBar should let users add their own menu bar characters from images while keeping the existing RunCat character system fast and reliable. Users can import static images, GIFs, or multiple frame images. Static images can be animated by choosing one of three generated motion styles: bounce/breathe, sway/run, or pixel jitter/flicker. Pixelation is configurable for uploaded characters.

## Scope

This feature adds first-class custom characters to the existing status bar character pipeline.

Included:
- Import static images and GIF files.
- Import multiple still images as an ordered frame sequence.
- Persist custom character metadata and copied assets under Application Support.
- Show custom characters in Preferences next to built-in RunCat characters.
- Let users choose pixelation strength for uploaded characters.
- Let users choose one of three generated static-image motion styles.
- Render custom characters in the status bar preview and live status item.
- Delete custom characters and fall back safely if a selected custom asset disappears.

Not included:
- Manual crop editor.
- Per-frame drawing tools.
- Reordering frames after import.
- Cloud sync.
- Applying generated static-image motion on top of already animated GIF/frame-sequence imports.

## User Experience

In Preferences, the Running Cat section gains a Custom Characters group and an Import Character button.

Import behavior:
- For a single static image, NetBar asks for a display name, motion style, and pixelation strength.
- For a GIF, NetBar imports the decoded frames and asks for a display name and pixelation strength.
- For multiple selected image files, NetBar imports them in filename sort order as frames and asks for a display name and pixelation strength.

Custom character controls:
- Select custom characters from the same picker area as built-in characters.
- Rename and delete custom characters from the Custom Characters group.
- Static-image custom characters expose a motion style picker with:
  - Bounce/Breathe
  - Sway/Run
  - Pixel Jitter/Flicker
- Uploaded characters expose a pixelation selector:
  - Off
  - 2x
  - 3x
  - 4x
  - 6x
  - 8x

Default behavior:
- A newly imported static image uses Bounce/Breathe.
- Pixelation defaults to Off.
- If the current selected custom character is deleted or unreadable, NetBar selects the default built-in cat.

## Architecture

The current code treats `RunCatCharacter` as a built-in resource descriptor and renders frames from `Resources/RunCat/<id>/frame_N.png`. The new design introduces a small asset layer that can resolve either a built-in character or a custom character without changing the high-level status bar flow.

New units:
- `CustomCharacterStore`: owns metadata loading, saving, import, rename, and delete.
- `CustomCharacter`: persisted metadata for user-added characters.
- `CharacterAsset`: runtime descriptor that unifies built-in and custom characters for rendering.
- `CustomCharacterImageProcessor`: decodes GIFs, normalizes static images/frame images, generates static-image motion frames, and applies pixelation.

Existing units to update:
- `RunCatAnimation`: animate by a `frameCount` supplied from `CharacterAsset` instead of only `RunCatCharacter`.
- `StatusBarDisplayRenderer`: resolve and draw a `CharacterAsset` frame, whether bundled or custom.
- `StatusBarSettings`: continue to persist only the selected character id and shared built-in character controls.
- `PreferencesWindowController`: add import, custom character picker, rename/delete, motion, and pixelation controls.

## Storage

Custom assets live outside the app bundle:

```text
~/Library/Application Support/NetBar/CustomCharacters/
  manifest.json
  <custom-character-id>/
    original.<ext>        # single static image or GIF source
    originals/            # frame-sequence sources, when applicable
      frame_0.<ext>
      frame_1.<ext>
    frame_0.png
    frame_1.png
    ...
```

`manifest.json` stores:
- `id`
- `displayName`
- `sourceKind`: `staticImage`, `gif`, or `frameSequence`
- `frameCount`
- `frameWidth`
- `frameHeight`
- `motionStyle` for static images
- `pixelationScale`
- `createdAt`
- `updatedAt`

Custom ids use a stable prefix such as `custom.<uuid>`, keeping them distinct from built-in RunCat ids.

The original source is preserved so static-image motion and pixelation changes can regenerate derived `frame_N.png` files without degrading already processed frames.

## Import And Processing

Static image:
- Load with `NSImage`.
- Normalize to PNG frames sized for menu bar rendering.
- Generate a small frame set for the selected motion style:
  - Bounce/Breathe: 6 frames with subtle vertical offset and scale pulse.
  - Sway/Run: 6 frames with slight horizontal offset and alternating mirror/tilt-like crop positioning.
  - Pixel Jitter/Flicker: 6 frames with tiny pixel offsets and brightness/alpha variation.
- Apply pixelation after motion generation so all generated frames share the same configured pixel style.

GIF:
- Decode frames using ImageIO (`CGImageSource`) and preserve frame order.
- Cap extremely large frame counts to a reasonable maximum, such as 60 frames, by evenly sampling frames.
- Apply pixelation to each decoded frame.
- Animation timing continues to use NetBar's network-speed-based frame timer rather than GIF delay metadata, preserving existing behavior.

Frame sequence:
- Sort selected files by localized filename order.
- Load each image as one frame.
- Apply pixelation to each frame.
- Use the first readable image dimensions for character width/height, with later frames normalized into the same canvas.

## Rendering

Rendering keeps the current status item behavior:
- Status bar still renders a single retina `NSImage`.
- Text layout and character placement remain controlled by existing settings.
- Animation speed remains tied to network speed and `catSpeedMultiplier`.

The renderer resolves the selected id:
- Built-in id: load bundled `Resources/RunCat/<id>/frame_N.png`.
- Custom id: load `Application Support/NetBar/CustomCharacters/<id>/frame_N.png`.

Width uses `frameWidth * catScale`. Height uses the custom metadata frame height, clamped to fit the menu bar. Static generated frames should be transparent PNGs so arbitrary uploaded shapes blend with the menu bar.

Color controls remain limited to built-in template characters and the special googly-eyes renderer. Uploaded characters render with their own colors plus optional pixelation.

## Preferences Data Flow

`StatusBarSettings` continues to persist the selected character id. Custom-character metadata is stored in `CustomCharacterStore`, not in UserDefaults.

Preferences observes the store:
- The character picker combines built-in `RunCatCharacter.allCharacters` and `CustomCharacterStore.characters`.
- Import updates the store, selects the new custom id, and refreshes the preview.
- Rename updates metadata only.
- Motion and pixelation edits update custom metadata and regenerate derived frames from the preserved original source.
- Delete removes the folder and metadata. If deleted id is selected, settings switch to the default built-in cat.

Rotation:
- Custom characters can be selected directly.
- Character rotation remains built-in-only for the first version. This avoids mixing mutable/deletable user assets into the existing comma-separated built-in rotation pool.

## Error Handling

Import errors:
- Unsupported file type: show a localized alert.
- Unreadable/corrupt image: show a localized alert and do not change the selected character.
- Partial frame-sequence failure: import readable frames if at least one frame succeeds, and show a warning count.
- Write failure: show a localized alert and leave existing settings unchanged.

Runtime errors:
- Missing selected custom character: fall back to the default built-in cat.
- Missing custom frame: render frame 0 if available; otherwise fall back to the default built-in cat.
- Corrupt manifest: ignore invalid entries and keep valid custom characters.

## Testing

Unit tests:
- `CustomCharacterStore` persists, reloads, renames, and deletes metadata.
- Static image processing creates frames for all three motion styles.
- Pixelation settings are clamped and persisted in the manifest.
- GIF/frame-sequence imports produce expected frame counts and dimensions from test fixtures.
- Character resolution falls back to the default cat for missing custom ids.
- Status bar width calculation uses custom character frame dimensions.

Manual verification:
- Import one PNG/JPG and test all three motion styles.
- Import a GIF and confirm it animates.
- Import multiple PNG frames and confirm filename order.
- Toggle pixelation strengths and inspect preview/live menu bar rendering.
- Delete the currently selected custom character and confirm fallback.
- Run `swift test`.
- Run `./Scripts/build-app.sh`.

## Open Decisions Resolved

All three generated static-image motion styles are included. Bounce/Breathe is the default because it works best across arbitrary uploaded images.
