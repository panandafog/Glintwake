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
- `Build/FramePilot/ios-duo.json`: both Duo displays, when its runtime is installed.

Override `FRAMEPILOT_ROOT` or provide `FRAMEPILOT_CLI` for an existing executable.
The scene JSONs can also be opened in FramePilot's GUI. Re-run prepare after moving
the repositories or changing simulators. It fails if required mobile families are
missing rather than silently generating an incomplete set.

## Capture

```sh
sh Scripts/framepilot.sh capture ios
sh Scripts/framepilot.sh capture macos
sh Scripts/framepilot.sh capture ios-duo
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
sheet. iOS scenes mode uses a four-second settle (twelve seconds for Duo) and pixel stability checks, so
visual inspection is still necessary. Mac XCTest explicitly waits for readiness
and the 1280×800-point window before attaching a real window screenshot. Its
attachments are named `framepilot-<scene>` and kept always.

## Export

After a complete run without errors:

```sh
python3 Scripts/export-store-screenshots.py Build/FramePilot/Runs/<successful-run>
```

The exporter checks completeness, opaque PNGs, supported dimensions and visible
app content before
copying files into `AppStore/screenshots/<family>/<language>`. It refuses failed,
partial or duplicate matrices. Review every selected screenshot; do not submit
black/empty frames, stale UI, device permission dialogs or warning-sized exports.
No resizing, compositing or simulated UI is performed by this workflow.
The local Swift/ImageIO content check ignores the top/right status areas and
rejects an otherwise black launch frame. It does not verify scene correctness;
visual review of all selected images remains required.

The full matrix is 40 images: 24 for iPhone/iPad/Mac and 16 for both Duo displays.

## Duo posture preparation

`capture ios-duo` requires an interactive terminal. FramePilot creates a disposable
simulator per display and pauses with its exact name and UUID. Select that simulator
in Xcode's Device Hub, choose **Closed** for `primary` or **Open** for `primary-1`,
and wait for the selected screen to render. Only then press Enter in the capture
terminal. The second display uses a different temporary simulator; do not change
an existing personal simulator or confirm a black screen. Ctrl-C cancels with cleanup.
Posture preparation has a ten-minute timeout. The same configs work in FramePilot's
GUI using its display-ready confirmation.

Duo exports are stored under `AppStore/screenshots/iPhone-Duo/<display>/<language>`.
The exporter independently checks native sizes: outer 1398×2034, inner 2007×2853,
including their landscape equivalents. FramePilot's generic iPhone validator
currently emits a size warning for Duo; only that exact known warning is accepted
after checking the selected Duo display's dimensions. Other warnings still fail.
No image is resized to satisfy a screenshot slot.

## Verification status

All 40 images were captured and inspected on 2026-11-11. The successful mobile
run has 16 artifacts, the Mac run has 8 and the Duo run has 16, with zero errors
in each. Duo run: `2026-11-11T16-42-29Z-573D00B9`, build 4.
On the Duo simulator, an actual direction-button move changed the counter from
2/7 to 3/7. Closed → Open → Closed → Open preserved that counter, the traveller's
position and collected crystals. The outer screen uses the vertical layout;
the inner screen uses the existing board-and-controls layout. No app layout
changes were needed. This simulator check does not replace physical-device testing.
See `AppStore/release-checklist.md` and `AppStore/screenshots/README.md` for this
working tree's actual build/capture results. Preparing configs and compiling
adapters alone is not a claim that a screenshot set has been captured or reviewed.
