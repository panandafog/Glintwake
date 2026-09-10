# Glintwake

A small, offline SwiftUI sliding puzzle for iPhone, iPad, and Mac. Gather the gold
crystals, plan your stops, and reach the activated exit. One brake charge lets you
make a single-cell move when momentum alone is not enough.

## Run

Open `Glintwake.xcodeproj` in Xcode 16 or newer (validated with Xcode 26.6).

- **Glintwake** is the single app target and scheme: choose an iPhone/iPad
  (iOS 17+) or **My Mac** (native macOS 14+) as the run destination.
- The Mac build uses the macOS SDK, not Mac Catalyst or “Designed for iPad”.
- Choose your signing team if running on a physical device.

The checked-in Xcode project is ready to use; no external packages are needed.
`project.yml` is its XcodeGen source. After changing targets or file membership,
run `xcodegen generate` (XcodeGen is only a development tool).

## Play

- Swipe the board in eight directions, or press a direction button.
- You slide until a wall, boundary, or mint stop ring. Walls block diagonal corner cutting.
- Gold crystals are collected along the entire path and do not stop movement.
- Collect all crystals, then enter the exit. It catches you once activated.
- Red hazards end an attempt, including after collecting the last crystal.
- From route 3, arm **Brake** before a move to travel exactly one cell. One charge per attempt.
- Undo restores the complete previous state, including crystals and the brake.
- A level is passed only by collecting every crystal and reaching the exit within
  the **minimum move count**, computed by the solver for that board. Braking counts
  as one move; blocked input does not spend a move. The counter shows used/limit.
- Spending the last move without finishing ends the attempt. Undo or restart to retry.
- Hint shows a shortest remaining step only if the solution still fits the budget;
  otherwise it asks you to undo.
- Mac: Q W E / A D / Z X C; arrow keys for cardinal moves; B toggles the brake.

Progress, your current sequence of moves, opened levels, and completions are saved
locally. Existing saves remain compatible: old results exceeding the minimum no
longer receive completion checkmarks, but their levels and stored scores are retained.
Russian and English use standard `Resources/en.lproj/Localizable.strings` and
`Resources/ru.lproj/Localizable.strings` resources, selected by the system/app language.
Formatted values have complete localized format strings, including accessibility labels.

The play screen does not scroll: the board fits the space remaining after controls,
with a side-by-side arrangement in wide windows. Instructions live in Help.
The native Mac window starts at 420×640 and can shrink to 340×500 points.
Only the help and route picker sheets scroll.

## Audio

Six original synthesized effects cover sliding, crystals, braking, undo, failure,
and victory. A quiet 48-second stereo ambient composition loops during play.
**Sound** provides independent, persistent switches for effects and background music.
Audio pauses when the app becomes inactive; iOS respects silent mode and audio
interruptions. Disconnecting headphones turns off the background music.

All WAV files in `Resources/Audio` were synthesized specifically for this project
using sine waves and seeded noise, with no external samples or recordings. There
are no third-party audio licenses or attribution requirements. Regenerate them with
`python3 Scripts/generate-audio.py` (Python standard library only).

## MVP scope

Three authored introductory levels and deterministic generated levels after them.
The picker starts with twelve entries; **Add 12 levels** expands it without leaving
the picker. All opened and previously completed levels remain available for replay,
including generated levels beyond the first twelve. Opening the picker scrolls to
the current level. Levels are identified by number only.

New fields are constructed locally and validated with a breadth-first solver.
The same level number gives the same board for this version. The generator has a bounded retry count and a known-solvable fallback.
No server, account, ads, analytics, purchases, or third-party runtime dependencies.

The movement engine and generator are original Swift implementations. The initial
mechanical reference is [Inertia from Simon Tatham's collection](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/doc/inertia.html).

This is a proof of concept, not an App Store submission package. Remaining product
work includes playtesting and difficulty progression, broader accessibility and
device testing, final localization, store metadata, and release signing. The
current generator guarantees solvability, not a unique or aesthetically ideal route.

## Tests

```sh
swift test
xcodebuild -project Glintwake.xcodeproj -scheme Glintwake \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Core checks cover sliding, stopping, diagonals, hazards after the final crystal,
locked/active exits, brake use, all 12 starter routes, and deterministic generation
and solvability across 32 additional seeds. UI tests play the first route,
undo, request a hint, win, advance, change level, and restore a brake by undo.
They also exercise a board swipe and restore an unfinished session after relaunch.
Additional checks cover the optimal move budget, restoring an exhausted attempt,
undoing a detour, completion marks, catalog expansion past twelve, and independent
sound preferences across relaunch. iPhone direction buttons are 56×56 points.
Russian portrait/landscape checks ensure that vertical swipes leave the board in
place and that controls fit within the window without scrolling.

Source layout:

- `Sources/Core`: Foundation-only rules, BFS solver, seeded generation.
- `Sources/App`: SwiftUI screens, rendering, input, local session persistence.
- `Tests/CoreTests`: Swift Testing, run with Swift Package Manager.
- `Tests/UITests`: XCTest, run with the iOS scheme.
- `Scripts/render-icon.swift`: reproducible original icon, drawn with AppKit.

Regenerate the icon with:

```sh
xcrun swift Scripts/render-icon.swift Assets/Assets.xcassets/AppIcon.appiconset
```

