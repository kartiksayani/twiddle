# Owner's manual check

Run `make install`, then open `/Applications/Twiddle.app`. These are the checks that need your eyes or a real login. Focus, Spaces, full screen, the hotkey recorder and dragging were verified in the running app; the evidence is in PRs #1 and #7. No permission prompt should appear during normal use.

- [ ] Material, dark: in Twiddle Settings choose Dark, close Settings, put a busy text window behind the panel, summon with `⌃⌥Space`, type a wrong key then the correct one, and toggle hints with `⌘/`. Expect blurred translucent material, legible typed/upcoming text, caret, errors and hints, with no clipping.
- [ ] Material, light: repeat the preceding steps with Light, over both bright and dark busy windows. Expect the same legibility and a light translucent surface.
- [ ] Motion: summon and dismiss repeatedly with the hotkey, then dismiss with Escape. Expect a 180 ms ease-out fade-in rising 8 pt, and a 120 ms fade-out without movement, scale or bounce.
- [ ] Menu icon: click Twiddle's icon; expect the menu to open with Practise, a disabled Today line, Progress, Settings… and Quit Twiddle, and no Dock icon.
- [ ] Practise: click it; expect the typing panel. Type at least 50 correct characters, hide, reopen the menu; expect Today to refresh and remain unclickable.
- [ ] Progress: click it; expect Today, the run chart and weakest keys (or zero values and the first-run note). Type a character; expect practice to return and count that character.
- [ ] Settings…: click it; expect the practice panel to hide and a legible Settings window to open without switching Spaces. Close it; expect focus back in the previous app.
- [ ] Quit Twiddle: click it; expect the icon and windows to disappear. Reopen the installed app; expect the icon back and saved Flow text/stats to survive.
- [ ] Live theme: in Settings choose Light, Dark, then System; expect its colours to change immediately. Close Settings and summon after each; expect matching panel colours. Leave System selected and Settings open, change macOS Appearance; expect Settings to update without relaunch. Close Settings and summon; expect the panel to match too.
- [ ] Login: enable Launch at login, close and reopen Settings; expect it still on with no error. Log out of macOS and really log back in; expect Twiddle's icon without manually opening it, and the saved hotkey to summon. Disable Launch at login and repeat a real login; expect no Twiddle icon until opened manually.
- [ ] Audio: start music in your usual player, summon, type for a minute, switch Flow/Sprint and dismiss. Expect uninterrupted playback throughout.
- [ ] Finished pill: open the panel, type, and run `open -g twiddle://done` from another terminal. Expect the pill for 10 s, with focus and typing unaffected. Hold `⌘` while it shows and expect the capsule to take its place. Press Escape and expect both gone.
- [ ] Paste: copy a paragraph, summon, press `⌘V`. Expect that text with no macOS prompt, and a `Pasted` header. Copy an image or nothing, press `⌘V`, and expect the note `Nothing to practise in the clipboard`. Quit and reopen; expect your default source, and the pasted text gone.
- [ ] Capsule: drag the panel to the top of the screen and hold `⌘`. Expect the two-row capsule fully on screen, with the panel not moving.
- [ ] Code packs: press `⌘2` repeatedly. Expect fresh text and the header to step through `Code · Go`, Python, TypeScript, SQL, Shell, then `Code`. Relaunch and expect the pack to stick.
- [ ] Progress height: open `⌘P` near the bottom of the screen, then near the top. Expect the taller view fully on screen each time. The bottom edge stays put when there's room above, and otherwise the panel shifts down just enough to fit.
- [ ] Ghost: run two sprints of the same length. Expect a faint caret moving smoothly in the second, and `New best` on the result whenever you beat your best for that length.
