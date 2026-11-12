# Glintwake

A small, offline SwiftUI sliding puzzle for iPhone, iPad, and Mac. Gather the gold
crystals, plan your stops, and reach the activated exit using sliding moves.

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
- Undo restores the complete previous state, including collected crystals.
- A level is passed only by collecting every crystal and reaching the exit within
  the **minimum move count**, computed by the solver for that board. Blocked input
  does not spend a move. The counter shows used/limit.
- Spending the last move without finishing ends the attempt. Undo or restart to retry.
- Hint shows a shortest remaining step only if the solution still fits the budget;
  otherwise it asks you to undo.
- Mac: Q W E / A D / Z X C; arrow keys for cardinal moves.

Only the current board, its move history, a one-time completion flag, and solved
counts for each difficulty are saved locally. The actual board is stored, so a
generator update cannot replace an unfinished puzzle. Undoing or restarting a
completed board never increments the count again. Switching difficulty or choosing
**Another puzzle** replaces the board without incrementing any count.

Old v1/v2 saves migrate to v3 sliding-only rules. An old attempt restarts from the
beginning with a freshly solved minimum; if the old board is unsolvable without the
removed ability, a validated board of the same difficulty replaces it. Solved counts
are retained, and a retained board keeps its one-time completion flag. Older save
data remains available as a backup. v1 history predates difficulty counters and is
not assigned to them.

Russian and English use standard `Resources/en.lproj/Localizable.strings` and
`Resources/ru.lproj/Localizable.strings` resources, selected by the system/app language.
Formatted values have complete localized format strings, including accessibility labels.

The play screen does not scroll: the board fits the space remaining after controls,
with a side-by-side arrangement in wide windows. Instructions live in Help.
The native Mac window starts at 420×640 and can shrink to 340×500 points.
Only the help and difficulty picker sheets scroll.

## Audio

Five original synthesized effects cover sliding, crystals, undo, failure,
and victory. A quiet 48-second stereo ambient composition loops during play.
**Sound** provides independent, persistent switches for effects and background music.
Audio pauses when the app becomes inactive; iOS respects silent mode and audio
interruptions. Disconnecting headphones turns off the background music.

All WAV files in `Resources/Audio` were synthesized specifically for this project
using sine waves and seeded noise, with no external samples or recordings. There
are no third-party audio licenses or attribution requirements. Regenerate them with
`python3 Scripts/generate-audio.py` (Python standard library only).

## MVP scope

There is no numbered campaign or level catalog. Choose a difficulty and solve an
endless stream of locally generated puzzles. After a win the next board is prepared
in the background; **Next level** opens it. Generation never blocks the play screen
when changing difficulty or requesting another puzzle.

| Difficulty | Crystals | Minimum solution | Mean safe choices on the solved route |
| --- | --- | --- | --- |
| Easy | 2 | 3–6 moves | ≥ 1 |
| Medium | 4 | 7–10 moves | ≥ 2 |
| Hard | 5 | 11–16 moves | ≥ 2.8 |

All boards stay 7×7. The generator checks exact shortest paths with breadth-first
search and filters by distinct safe continuations along an optimal route. This is
an initial geometry check. Medium and hard boards additionally pass an exact
collection-order assessment (`RouteAssessment`):

- The greedy player always heads for a crystal reachable in the fewest moves.
  Every equally near target and every shortest approach are considered, choosing
  the best complete outcome among them. A direction tie-break cannot inflate difficulty.
- Medium requires this greedy player to need at least one extra move (or get stuck);
  hard requires at least two extra moves (or get stuck).
- Across all optimal solutions, at least one collection stage must deliberately
  skip the nearest crystals. Ordinary travel and undo do not count as decisions.
- Exact reachability and the original minimum-move ranges remain mandatory.

These are targeted tests against obvious collection strategies, not a calibrated
prediction of human solving time. New filters apply to newly generated boards;
saved current boards are restored as before.
Hard puzzles use longer construction walks and a larger candidate budget. For each
new hard puzzle, the generator privately chooses a desired length uniformly from
11–16 before searching. It searches up to four batches of 1,800 layouts, returning
an exact length match when found, otherwise the closest validated board. This
reduces the bias toward eleven-move puzzles without requiring player settings or
changing the minimum-move rule. Rare lengths are not guaranteed equal frequency. Search
is bounded and each mode has a fixed, solver-verified fallback within its profile,
including the collection-order requirements.
The legacy numbered generator remains solely for save migration and regression tests.
No server, account, ads, analytics, purchases, or third-party runtime dependencies.

The movement engine and generator are original Swift implementations. The initial
mechanical reference is [Inertia from Simon Tatham's collection](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/doc/inertia.html).

App Store preparation is in [AppStore/release-checklist.md](AppStore/release-checklist.md),
with EN/RU metadata, privacy policy and support pages. Screenshot scenes and
FramePilot setup are documented in [Docs/FramePilot.md](Docs/FramePilot.md).
Signed archive validation, App Store Connect fields and device/TestFlight checks
remain release gates; local preparation does not submit or publish the app.
Release automation and the one-time GitHub/Apple setup are documented in
[App Store release automation](Docs/APP_STORE_RELEASE_AUTOMATION.md). The manual
GitHub workflow prepares a Draft Review Submission; the owner presses Submit for Review.
The generator guarantees solvability, not a unique or aesthetically ideal route.

## Tests

```sh
swift test
xcodebuild -project Glintwake.xcodeproj -scheme Glintwake \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Core checks cover the movement rules, legacy generation, 20 seeds per difficulty,
rejection of obvious routes, exact order penalties, rotation and gem-order invariance,
a 40-seed check against concentration at eleven moves,
profile-specific fallback boards, and completion credit across undo, restart,
serialization, and puzzle replacement, plus migration of old movement rules.
UI tests cover a full restart after exhausting the move limit, the strict move limit,
one-time counters, next puzzle, changing difficulty, skipping a puzzle, restoring
the exact current board, sound preferences, and Russian portrait/landscape layouts.
iPhone direction buttons remain 56×56 points; the play screen never scrolls.

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

