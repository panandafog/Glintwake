# Glintwake screenshots with FramePilot

FramePilot is local tooling from `../FramePilot`, not an app dependency. The app
has one appearance, so presets capture dark only. Languages: en-US and ru-RU.

## Prepare

```sh
xcodegen generate
sh Scripts/framepilot.sh prepare
```

This builds the local CLI and inspects the project/device inventory. It does not
launch apps, boot simulators or capture screens. Ignored machine-specific configs:

- `Build/FramePilot/ios.json`: large iPhone + 13-inch iPad, scenes mode.
- `Build/FramePilot/macos.json`: native Mac, opt-in `Glintwake Screenshots` UI-test scheme.

Override `FRAMEPILOT_ROOT` or provide `FRAMEPILOT_CLI` for an existing executable.
The scene JSONs can also be opened in FramePilot's GUI. Re-run prepare after moving
the repositories or changing simulators. It fails if required mobile families are
missing rather than silently generating an incomplete set.

## Capture

```sh
sh Scripts/framepilot.sh capture ios
sh Scripts/framepilot.sh capture macos
```

Results and diagnostics are stored in unique directories under
`Build/FramePilot/Runs`. Mobile capture uses disposable simulators; do not point
captures at a physical device. Mac capture needs an unlocked GUI session and UI
Automation permission for Xcode/Test Runner. Close your regular Glintwake before
Mac capture because XCTest launches and terminates this app's bundle identifier.

Only the dedicated screenshot scheme includes `ScreenshotTests`; ordinary
Glintwake tests and Archive do not run captures. Archive remains Release. Build
capture adapters without launching UI:

```sh
xcodebuild -project Glintwake.xcodeproj -scheme 'Glintwake Screenshots' \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath Build/FramePilot/Verification CODE_SIGNING_ALLOWED=NO build-for-testing
```

## Four actual game scenes

| Argument | Content |
| --- | --- |
| `--screenshot-scene=gameplay` | Medium puzzle after two real solution moves |
| `--screenshot-scene=planning` | Hard puzzle with an actual next-move hint |
| `--screenshot-scene=difficulty` | Difficulty sheet with illustrative solved counts |
| `--screenshot-scene=victory` | Medium puzzle solved with its shortest route |

These are fixed, solver-verified boards shown by the ordinary game UI. There is no
special marketing view. Fixtures and screenshot argument handling are inside
`#if DEBUG`. Scenes disable game persistence and audio and do not load saved player
progress; they never overwrite the normal save or sound preferences. Unknown scene
names remain isolated and do not expose readiness. Release ignores screenshot and
UI-test arguments. `Scripts/verify-release.py` scans built Release bundles for them.

Readiness markers are `screen.<scene>`; the difficulty marker belongs to the actual
sheet. iOS scenes mode uses a four-second settle and pixel stability checks, so
visual inspection is still necessary. Mac XCTest explicitly waits for readiness
and the 1280×800-point window before attaching a real window screenshot. Its
attachments are named `framepilot-<scene>` and kept always.

## Export

After a complete run without errors:

```sh
python3 Scripts/export-store-screenshots.py Build/FramePilot/Runs/<successful-run>
```

The exporter checks completeness, opaque PNGs and supported dimensions before
copying files into `AppStore/screenshots/<family>/<language>`. It refuses failed,
partial or duplicate matrices. Review every selected screenshot; do not submit
black/empty frames, stale UI, device permission dialogs or warning-sized exports.
No resizing, compositing or simulated UI is performed by this workflow.

The intended matrix is 24 images: 4 scenes × 2 languages × iPhone/iPad/Mac.
iPhone Duo is not selected automatically: it needs a separate two-display posture
workflow, and Apple's current requirement starts in April 2027 for iOS 27.1+ SDK
submissions. Check the current Apple specification before a later submission.

## Verification status

All 24 images were captured and inspected on 2026-11-11. The successful mobile
run has 16 artifacts and the successful Mac run has 8, with zero errors in both.
See `AppStore/release-checklist.md` and `AppStore/screenshots/README.md` for this
working tree's actual build/capture results. Preparing configs and compiling
adapters alone is not a claim that a screenshot set has been captured or reviewed.
