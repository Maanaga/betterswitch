# Window Preview Thumbnails

## Goal

Add a Settings-selectable switcher layout that shows visual previews of open windows while preserving the current Betterswitch UI as the default/classic experience.

The feature should help users identify the correct window faster when multiple windows share similar app names or titles, especially in browsers, editors, terminals, Finder, and design tools.

## User-Facing Behavior

Betterswitch should offer two switcher display modes:

- `Classic List`: the current Betterswitch UI, with app icon, app name, window title, bundle detail, search, and keyboard navigation.
- `Preview Thumbnails`: a richer UI that includes a thumbnail preview for each visible window.

The user chooses the mode from Settings. The choice should persist across launches.

## Settings

Add a new Appearance setting:

```text
Switcher layout
[ Classic List      v ]
```

Available values:

- `Classic List`
- `Preview Thumbnails`

Recommended default:

- `Classic List`

Reasoning: this preserves current behavior for existing users and makes the v2.0.0 feature opt-in.

## Preview Layout

The preview layout should keep the same core behavior as the current switcher:

- opens from the same global shortcuts
- searches apps and window titles
- supports Up, Down, Return, and Escape
- uses the same selected-window state
- uses the same activation behavior
- respects the existing glass darkness setting

Suggested visual structure:

```text
Search apps and windows

┌───────────────────────────────────────────────┐
│ [thumbnail]  Chrome                           │
│              Linear - Roadmap                 │
│              com.google.Chrome                │
└───────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐
│ [thumbnail]  Xcode                            │
│              Betterswitch                     │
│              com.apple.dt.Xcode               │
└───────────────────────────────────────────────┘
```

Thumbnail sizing:

- fixed thumbnail width around `140-180pt`
- fixed thumbnail height around `88-112pt`
- rounded corners around `8-12pt`
- use aspect-fit or aspect-fill consistently
- avoid row height changes while thumbnails load

If the panel is narrow, the layout can use a smaller thumbnail size rather than hiding metadata.

## Thumbnail Source

Use macOS window imagery when available.

Preferred approach:

1. Capture window thumbnails using the ScreenCaptureKit APIs where available.
2. Fall back to the app icon plus a neutral placeholder if no window image can be captured.

Do not use `CGWindowListCreateImage` for this feature. It is unavailable in the macOS 26 SDK and has been replaced by ScreenCaptureKit.

The placeholder should look intentional, not broken. It can show:

- app icon
- app name initials or app name
- subtle glass/material background

## Permissions

Window previews may require Screen Recording permission depending on the capture path and macOS behavior.

Settings and first-run behavior should handle this clearly:

- If the user selects `Preview Thumbnails` and permission is missing, show a clear message in Settings.
- The switcher should still open even when previews cannot be captured.
- Missing preview permission should not block classic switching.
- If permission is unavailable, rows should use the fallback placeholder.

Suggested Settings copy:

```text
Window previews may require Screen Recording permission. If previews are unavailable, Betterswitch will continue showing app icons.
```

Do not request extra permission unless the user enables preview mode or opens a flow that needs previews.

## Data Model Changes

Add a persisted preference for switcher layout.

Suggested type:

```swift
enum SwitcherLayout: String, CaseIterable, Codable {
    case classicList
    case previewThumbnails
}
```

Add to `PreferencesModel`:

- stored `switcherLayout`
- setter method
- UserDefaults key
- default value of `.classicList`

The switcher controller/view should receive or observe this preference.

## Architecture

Keep preview generation separate from scanning and activation.

Recommended components:

- `WindowScanner`: continues to discover windows and metadata.
- `WindowInfo`: remains mostly metadata-focused, but may need a stable window identifier for preview capture.
- `WindowPreviewProvider`: async service that loads thumbnails for `WindowInfo`.
- `WindowSwitcherView`: chooses between classic rows and preview rows based on `switcherLayout`.
- `PreviewThumbnailCache`: small in-memory cache keyed by stable window identity.

This keeps capture logic out of SwiftUI rows and avoids mixing permissions, caching, and image loading directly into the view.

## Stable Window Identity

Preview capture needs a reliable way to map `WindowInfo` to the actual system window.

Current `WindowInfo.id` can be based on AX index/title or CG window number. For previews, prefer carrying the CG window number when available.

Suggested addition:

```swift
let windowNumber: Int?
```

Fallback matching can use:

- process identifier
- title
- bounds
- bundle identifier

The implementation should avoid relying only on window title, because browser tabs, untitled documents, and repeated Terminal windows can collide.

## Loading Behavior

The switcher should feel instant.

Recommended loading strategy:

1. Show rows immediately with placeholders.
2. Start thumbnail loading after `refreshWindows()`.
3. Update visible rows as thumbnails arrive.
4. Cache thumbnails for the current switcher session.
5. Clear stale cache entries when windows disappear.

Avoid blocking `show()` on image capture.

## Performance Targets

The preview mode should not make Betterswitch feel slower than classic mode.

Targets:

- switcher appears immediately after shortcut
- no synchronous thumbnail capture on the main thread
- smooth Up/Down selection while thumbnails load
- bounded memory usage
- no repeated recapture on every small selection movement

Suggested cache limit:

- keep thumbnails for the current `windows` list
- optionally cap to around `50` thumbnails

## Edge Cases

Handle these cases gracefully:

- Screen Recording permission missing
- Accessibility permission missing
- minimized windows
- hidden apps
- full-screen spaces
- windows on another display
- secure/protected windows that cannot be captured
- windows with identical titles
- windows that close while thumbnails are loading
- many browser windows/tabs

For unavailable previews, show the fallback placeholder and keep switching functional.

## Implementation Steps

1. Add `SwitcherLayout` preference.
2. Add the setting to `OptionsView` under Appearance.
3. Pass or inject preferences into the switcher view/controller.
4. Add `windowNumber` or equivalent stable capture identity to `WindowInfo`.
5. Create `WindowPreviewProvider`.
6. Create thumbnail cache.
7. Add `PreviewWindowRow`.
8. Update `WindowSwitcherView` to render either classic rows or preview rows.
9. Add permission/error state handling for unavailable previews.
10. Test classic mode to ensure existing behavior is unchanged.
11. Test preview mode with multiple apps, multiple displays, and permission denied/granted states.

## Acceptance Criteria

- User can choose `Classic List` or `Preview Thumbnails` in Settings.
- The selected layout persists after quitting and reopening Betterswitch.
- Classic mode looks and behaves like the current UI.
- Preview mode shows thumbnails for windows when available.
- Preview mode falls back cleanly when thumbnails are unavailable.
- Search, keyboard navigation, mouse selection, and activation work in both modes.
- Opening the switcher is not delayed by thumbnail capture.
- No crash occurs if windows close during thumbnail loading.

## Release Notes Draft

```text
New in Betterswitch 2.0.0: optional window preview thumbnails. Choose the new Preview Thumbnails layout in Settings to see visual previews of your open windows while switching. The classic Betterswitch list remains available and is still the default.
```
