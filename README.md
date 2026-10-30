# Twiddle

Twiddle is a menu-bar macOS app for short typing practice in a small panel over your current app. Choose continuous Flow or a timed Sprint, with words, code, prose or practice for your weakest keys.

## Build and install

Requires an Apple silicon Mac running macOS 26 and Xcode 26 with its command-line tools selected. From the repository directory, run:

```sh
make install
open /Applications/Twiddle.app
```

`make install` builds a release app and copies it to `/Applications/Twiddle.app`, replacing an existing copy. Twiddle is ad hoc signed, so build it locally on the Mac where you will use it.

## Use

Press Control–Option–Space (`⌃⌥Space`) to summon the panel on the display under the pointer. Press Escape, press the hotkey again, or click another window to dismiss it; Flow resumes at the start of your unfinished word.

While the panel is open:

- `⌘F` selects Flow; `⌘S` selects Sprint, then cycles 15, 30 and 60 seconds on further presses.
- `⌘1`–`⌘4` select Words, Code, Prose and Weak keys.
- `⌘/` toggles finger hints; `⌘P` shows Progress.
- Hold `⌘` to see the available commands.

The menu-bar icon also opens Practise, Progress and Settings.

## Change the hotkey

Open Settings from the menu-bar icon, or press `⌘,` in the panel. Click Summon hotkey and type a shortcut containing Command, Control or Option; Escape cancels and Backspace clears it. If a conflict appears, choose another shortcut; Practise in the menu bar remains available.

## Data

Twiddle stores practice data only in `~/Library/Application Support/Twiddle` (`state.json`); nothing is uploaded. Preferences such as the hotkey and theme use macOS UserDefaults, and macOS manages Launch at login.
