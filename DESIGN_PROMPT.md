**Design a tiny macOS utility: Twiddle, a typing practice panel for the moments you're waiting**

**The problem.** I keep hitting short waits with no known length: a coding agent is working in my terminal, someone is about to reply on Slack, a page is loading, or I'm just listening to music. I want to use those moments to practise typing. Typing apps and sites don't fit, because they take me to another window or desktop and ask me to commit to a session. I need something like Spotlight or superwhisper: I press a hotkey, a small panel appears right where I am, I type, and I press a key to make it vanish.

**Who uses it.** One engineer, me. I'm fast, but with bad habits and a few keys I still reach for by eye. My hands are on the keyboard, and whatever I'm waiting on stays on screen. The panel should feel like a quiet part of macOS, never like an app I've entered.

**Data model.**
- **Mode:** Flow (endless, no timer, the default) or Sprint (15, 30 or 60 seconds).
- **Content source:** Words, Code, Prose, or Weak keys.
- **Run:** `mode`, `source`, `started_at`, `active_seconds`, `wpm`, `accuracy`, `chars_typed`.
- **Key stat:** `key` or letter pair, `average_ms`, `error_rate`.
- **Today:** `minutes_practised`, `average_wpm`, `best_wpm`.

**Screens and views:**
1. **Practice panel, Flow (main).** The whole product. A small floating panel with a few lines of text, a caret, and clear states for typed, correct, mistyped and upcoming characters. Live WPM and accuracy stay quiet at the edge. Design the exact size, and show it floating over a busy desktop, so I can judge how much of my screen it takes. Whatever I'm waiting on must stay visible.
2. **Summoned and resumed.** The panel arriving, and picking up where I left off, so I can start typing with no reorientation.
3. **Sprint.** The same panel with a countdown, then a compact result card. Show how I start another run, or return to Flow, without touching the mouse.
4. **Content and mode switching.** How I change between Words, Code, Prose and Weak keys, and between Flow and Sprint. Show one sample of each, because Code needs symbols and indentation, and Prose needs capitals and punctuation.
5. **Finger hints.** An optional compact keyboard map, off by default, showing which finger should hit the next key, using standard QWERTY touch-typing zones. It shows the correct finger only and never grades me. Show how it fits the panel, on and off.
6. **Progress.** A small view: today's numbers, a recent WPM trend, and my weakest keys. A glance, not a dashboard.
7. **Settings.** Hotkey recorder, launch at login, default mode and source, finger hints on or off, theme.
8. **Menu bar.** The icon and its short menu.
9. **First run.** The shortest possible introduction: the hotkey, and how to dismiss.

**Interactions.** Everything works from the keyboard, and typing keys always go to the text, so every command needs a modifier chord or a dedicated key. Please propose the full keyboard map. `Esc` dismisses, always. Also design how mistakes behave (does the caret stop, or move on? how does Backspace work?), what happens after I go idle, and what the panel does when I click away to another app: it hides, and resumes next time. No sounds.

**Visual direction.** Native macOS, calm and very small, closer to Spotlight or Raycast than to Monkeytype. Translucent material is welcome if the text stays perfectly legible. The practice text is the hero: a monospaced face, large enough to read at a glance. Almost no chrome and no marketing. Mistakes are shown by more than colour alone. Light and dark themes.

**What to deliver.**
- All nine views above, in high fidelity.
- Light and dark variants of the practice panel and the result card.
- A clickable HTML prototype of the summon, type, dismiss and resume loop.
- The full keyboard map.
- A component sheet: practice text states, stat readout, mode and source switcher, key map, trend chart, keycap chip.
- Design tokens: colour, type, spacing, radius.
- Annotated sizes and spacing, ready for a SwiftUI build.

**Example data to design with.**
- **Words:** `there might still think about small early because around another people`
- **Code:** `if err := run(ctx); err != nil { return fmt.Errorf("sync: %w", err) }`
- **Terminal:** `git rebase -i HEAD~3 && git push --force-with-lease origin main`
- **Prose:** `Two roads diverged in a wood, and I took the one less travelled by, and that has made all the difference.`
- **Weak keys:** `query equip zebra jazzy quick pixel maxim oxide`
- **Live stats:** 78 WPM, 96.4% accuracy.
- **Sprint result:** 30 seconds, 84 WPM, 97.1% accuracy, 3 mistakes, slowest pair `br`.
- **Today:** 11 minutes, 76 average WPM, 91 best.
- **Weakest keys:** `q`, `z`, `[`, `]`, `-`.
