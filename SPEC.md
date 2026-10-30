# Twiddle spec

Twiddle is a menu-bar macOS app. A global hotkey shows a small typing panel on the current Space, and the panel never takes focus away from the app behind it.

Sources of truth:
- `designs/Twiddle.dc.html`: views, sizes, tokens, keyboard map.
- `designs/Panel.dc.html`: exact panel layout, palettes, finger map.
- `designs/Twiddle Prototype.dc.html`: interaction logic for reference only. It's a prototype, not a code model.
- This file wins on data and behaviour. The designs win on look and feel.

## Stack

| Area | Decision |
|---|---|
| Language | Swift 6 language mode, strict concurrency |
| UI | AppKit shell, SwiftUI views hosted inside it |
| Target | macOS 26, Apple silicon |
| Build | Swift Package Manager, plus `scripts/build-app.sh` to assemble and ad hoc sign `Twiddle.app`. `Makefile` targets: `check`, `app`, `install`. |
| Tests | Swift Testing |
| Lint | `swift format lint --strict` |
| Dependencies | None |

## Package layout

```
Package.swift
Sources/TwiddleCore/       Foundation only. No AppKit, no SwiftUI.
  TypingSession.swift      caret, pending mistake, mistake marks; strict and forgiving
  TextLayout.swift         wraps text into lines of at most 46 characters
  ContentProvider.swift    endless text per source
  StatsTracker.swift       active time, WPM, accuracy, run boundaries
  KeyStats.swift           per-key and per-pair latency and errors
  FingerMap.swift          QWERTY character to key, finger and Shift
  PracticeModel.swift      mode, source, view, sprint state, command handling
  Store.swift              JSON persistence
  Resources/               words.txt, code.txt, prose.txt, drills.txt
Sources/TwiddleUI/         SwiftUI views. Render from state, with no window or app dependency.
  Views/                   panel, practice text, header, result, progress, hints, capsule, intro
  Theme.swift              design tokens
Sources/Twiddle/           App target.
  AppDelegate.swift        startup and wiring
  PanelController.swift    NSPanel lifecycle, placement, click-away, animation
  KeyRouter.swift          NSEvent to text input or Command
  HotkeyCenter.swift       Carbon registration
  StatusMenu.swift         NSStatusItem and NSMenu
  SettingsWindow.swift     NSWindow hosting the settings form
Tests/TwiddleCoreTests/
Tests/TwiddleUITests/      SnapshotExport renders fixture states to PNG with ImageRenderer
scripts/build-app.sh
scripts/check-coverage.sh  fails if TwiddleCore line coverage is under 85%
```

Each file above is a guide, not a quota. Keep a type in the file that reads best, but keep the boundaries strict: everything testable lives in `TwiddleCore`, views live in `TwiddleUI`, and time and randomness are injected.

`PracticeModel` is `@Observable` and `@MainActor`. It's the only owner of practice state. Views read it, and `KeyRouter` sends it `Command` values and typed characters.

## Window behaviour

- `NSPanel` subclass with `.nonactivatingPanel` and `.fullSizeContentView` at `.floating` level, with `canBecomeKey` returning `true`. Collection behaviour: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.transient`.
- Hide with `orderOut`, so the panel doesn't linger on other Spaces.
- Twiddle uses `.accessory` activation and `LSUIElement`. It never activates to show the panel.
- Show on the screen under the mouse pointer.
- Default position: centred, 40 pt above the bottom of `visibleFrame`.
- A dragged position is stored as an offset from that default and clamped to the current `visibleFrame`. A double-click on the header clears it.
- Height is fixed by view: 136 pt, or 252 pt with hints. The bottom edge stays put and the panel grows upwards, so the text moves up 116 pt when hints open. Clamp so the top stays on screen.
- Click-away: hide on `windowDidResignKey`, and use a global `leftMouseDown` monitor while visible. The click still reaches the other app.
- The ⌘ capsule is a borderless child panel, 10 pt above the main panel, that ignores mouse events.
- Motion: summon is 180 ms ease-out with an 8 pt rise; hide is a 120 ms fade. No scale, no bounce.

## Keyboard

- The panel routes `keyDown`, `flagsChanged` and `performKeyEquivalent` into `KeyRouter`. Twiddle has no main menu, so `KeyRouter` handles ⌘ chords itself.
- Follow the board's keyboard map. Esc hides in every state.
- Text input uses `event.characters`. Ignore `isARepeat` for text, so holding a key is one press. `Backspace` may repeat.
- Ignore events with an empty `characters` string, such as a dead key.
- Holding ⌘ for 300 ms shows the capsule. Releasing it, or losing key status, hides it.
- The hotkey uses Carbon `RegisterEventHotKey` with `kEventHotKeyExclusive`, which needs no permissions. A registration failure shows the Settings conflict state. Also check `CopySymbolicHotKeys`, so enabled macOS shortcuts count as conflicts.
- If `⌃⌥Space` itself conflicts at launch, the panel still opens from the menu bar and Settings shows the conflict.

## Typing rules

`TypingSession` holds `text`, `caret`, `pending` (the wrong key waiting to be fixed, strict only) and `mistakes` (a set of text offsets).

| Input | Strict (default) | Forgiving |
|---|---|---|
| Correct key | Advance. Clear `pending`. | Advance. |
| Wrong key | Stay, set `pending`, mark the offset. | Mark the offset and advance. |
| Backspace | Clear `pending` only. | Step back one and clear that offset's mark. |
| ⌥Backspace | Same as Backspace. | Move to the word start and clear marks from there on. |
| Return | Types `\n`. It's ignored unless the expected character is `\n`. | Same. |
| Tab | Ignored. | Ignored. |

- After a correct `\n`, skip leading spaces on the next line.
- A mistyped space shows `·` as the expected glyph and `␣` as the key tag.
- The text buffer is extended when fewer than 300 characters remain.
- Changing Mistakes in Settings takes effect on the next summon and clears `pending`.

## Stats

Two counters per scope:
- `netCorrectChars`: rises on a correct key and falls when Forgiving Backspace removes a correct character.
- `presses` and `correctPresses`: every text press counts. They never fall.

Formulas:
- WPM = `netCorrectChars` ÷ 5 ÷ active minutes.
- Accuracy = `correctPresses` ÷ `presses`.
- Active time: add the gap since the previous press only when it's under 10 s.

Scopes and boundaries:
- Flow's header shows today's rolling numbers.
- Sprint's header shows the current sprint. Its active time is elapsed sprint time. It shows `–` until the first key.
- At 10 s idle, the header shows `Paused` and the caret blinks.
- A Flow run ends on hide or after 5 idle minutes. Save it to history only if it has at least 50 net correct characters. Shorter runs still feed today's numbers and key stats.
- A Sprint run is saved only when it completes. Hiding during a sprint cancels it. Summoning in Sprint mode gives fresh text in the ready state.
- Sprint mistakes count marked offsets, not presses.

Key stats:
- Latency is the gap between two consecutive correct presses. Skip it if the gap is 2 s or longer, or if a mistake came between them.
- Pairs cover two consecutive letters, lowercased. The sprint's slowest pair needs at least 2 samples, otherwise it shows `–`.
- Each key keeps a sample count plus exponential moving averages (α = 0.1) of latency and error rate.
- Weakest-key score = `averageMs × (1 + 2 × errorRate)`, for keys with at least 20 samples.
- Progress shows the top five with their average ms.

## Content

| Source | Text |
|---|---|
| Words | Random picks from `words.txt`: about 1,000 common lowercase words. |
| Code | Lines from `code.txt`: about 60 Go, TypeScript and shell snippets, using real `\n`. |
| Prose | Random passages from `prose.txt`: about 40 passages. |
| Weak keys | Words ranked by how many of the five weakest keys they contain, mixed with symbol drills from `drills.txt`. |

- Every corpus is written for this project. Don't import third-party lists.
- Prose must be first published before 1931. Record author, work and year per passage.
- Corpora use printable ASCII and `\n` only. Every character must resolve through `FingerMap`. A test enforces both rules. Curly quotes and em dashes get normalized in the file.
- Weak keys needs five ranked keys. Until then it serves Words, and the header note says `Not enough data yet`.

## Persistence

`~/Library/Application Support/Twiddle/state.json`, Codable, with a `version` field and atomic writes. Write on hide, on run end and on quit, never per keystroke.

```
version
resume: [source: { text, caret, mistakes }]   text trimmed to the current line onwards
today: { date, activeSeconds, netCorrectChars, presses, correctPresses, bestWPM }
runs: [{ mode, source, startedAt, activeSeconds, wpm, accuracy, chars }]   newest 20
keys: [key: { samples, averageMs, errorRate }]
pairs: [pair: { samples, averageMs, errorRate }]
panelOffset, hintsOn, seenIntro, lastSprintLength
```

- `today` resets when the local date changes.
- Settings live in `UserDefaults`: hotkey, default mode, sprint length, default source, Mistakes, theme. Launch at login reads its state from `SMAppService`.
- A corrupt or newer-version file is renamed to `state.corrupt.json`, and Twiddle starts fresh. Stats are not worth a startup failure.
- Resume returns the caret to the start of the current word and drops `pending` and marks from there on.

## Views

Follow the board for every view. Added cases the board doesn't draw:
- Progress with no data: `0` values, an empty chart area and the note `Numbers appear after your first run`. Use existing type and colour tokens.
- The menu's `Today` line refreshes in `menuWillOpen`.
- The Progress time axis uses the weekday of the oldest listed run, then `now`.

`PracticeTextView` draws each line in a `Canvas` pass, with wavy and dotted underlines as `Path`s. Don't create a view per character.

Theme follows `NSApp.effectiveAppearance` unless overridden. Convert the board's `oklch` tokens once to sRGB constants in `Theme.swift`.

## Settings window

Our own `NSWindow`, 500 × 468 pt, hosting a SwiftUI form. Don't use the SwiftUI `Settings` scene, which is unreliable in accessory apps.

Opening it hides the panel, records `NSWorkspace.shared.frontmostApplication`, then activates Twiddle. Closing it reactivates the recorded app.

Launch at login uses `SMAppService.mainApp`. If registration fails, show the failure beside the toggle and leave it off.

## Milestones

| # | Result | Gate |
|---|---|---|
| M0 | Repo, package, app bundle script, quality gate, hook. An empty panel that summons and dismisses. | Panel shows on another Space and over a full-screen app, and the frontmost app doesn't change. |
| M1 | `TypingSession`, `TextLayout`, `StatsTracker`, `KeyStats`, `FingerMap` | Tests cover every row of the typing rules and each stats boundary. |
| M2 | Corpora, `ContentProvider`, `Store` | Corpus test passes. Store round-trip, day rollover and corrupt-file tests pass. |
| M3 | Flow panel: text, header, resume, idle, hide, tokens | Summon, type, hide, resume works in the running app. |
| M4 | Sprint, source and mode switching, capsule, result view | Full sprint loop works from the keyboard. |
| M5 | Finger hints, Progress, first run | Each view matches its board section. |
| M6 | Menu bar, Settings, hotkey recorder, launch at login | Rebinding and conflict states work. |
| M7 | Light and dark pass, visual check against the board, install | The checklist in `BUILD_PROMPT.md` passes. |

M0 tests the riskiest assumption first. If the panel can't keep focus behaviour on a real Space or full-screen app, stop there and fix it before anything else is built.

## Out of v1

Lessons, goals and streaks, accounts or sync, sounds, custom themes, importing text, non-QWERTY finger maps, App Store, notarization, auto-update.
