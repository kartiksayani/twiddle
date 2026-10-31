# Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-10-30 | Name is Twiddle. | Twiddling your thumbs is the idiom for waiting. |
| 2026-10-30 | Default hotkey is `⌃⌥Space`, rebindable. | Matches the board. `⌥Space` belongs to superwhisper. |
| 2026-10-30 | Both Strict and Forgiving mistakes ship in v1. Strict is the default. | Kartik's call after the board added Forgiving. |
| 2026-10-30 | Swift Package Manager with a bundle script, no Xcode project. | Diffable and easy for an agent to maintain. |
| 2026-10-30 | No dependencies. Carbon hotkey and our own recorder. | The board's recorder and conflict states are custom, and the wrapper is small. |
| 2026-10-30 | JSON file instead of SwiftData. | Small bounded data, simple to test. |
| 2026-10-30 | Stored resume text instead of a seed. | Survives corpus edits. |
| 2026-10-30 | `NSStatusItem` instead of `MenuBarExtra`. | The app is AppKit-led, with no SwiftUI `App` scene. |
| 2026-10-30 | Own settings `NSPanel`, non-activating. | SwiftUI's `Settings` scene is unreliable in accessory apps, and `NSApp.activate()` was declined in real use. |
| 2026-10-30 | Hints grow the panel upwards and the text moves up. | The board's prototype does this, and 40 pt below the panel can't hold 116 pt. |
| 2026-10-30 | Corpora are written for the project, and prose is pre-1931. | No third-party licences. |
| 2026-10-30 | Ad hoc signing. | Personal app, and no signing identity is installed. |
| 2026-10-30 | Public repo at `github.com/kartiksayani/twiddle`. | Kartik's call. Replaces the local-only plan. |
| 2026-10-30 | `designs/support.js` stays out of the repo. | It's generated Claude Design runtime, and the build doesn't need it. |
| 2026-10-30 | Codex `gpt-6.1-sol` at high effort implements and reviews, in separate threads. Claude architects and merges. | Kartik's call. |
| 2026-10-30 | Delivery follows `ORCHESTRATOR.md`, a tighter version of Ariadne's: PR per milestone, one gate, tables before code, visual evidence, enforced doc limits. | Keeps Ariadne's learnings without its growth. |
| 2026-10-30 | Views live in a separate `TwiddleUI` library. | They can be rendered to PNG in tests, so layout isn't written blind. |
| 2026-10-31 | Practice lines wrap at 44 characters, not the board's 46. | SF Mono's 14.84 pt advance fits 45 cells in 668 pt, and the last cell must hold a trailing space or `↵`. |
| 2026-10-31 | The macOS shortcut conflict check runs only while recording a new shortcut. | `⌃⌥Space` is macOS's enabled input-source shortcut, so checking at launch disabled Twiddle's own default. |
| 2026-10-31 | `lastSprintLength` is the only sprint-length value. | A second copy in UserDefaults overrode `⌘S` choices on relaunch. |
| 2026-10-31 | Twiddle is exempt from `security-guidance` and Seezo. | Kartik's call. It's a personal app, and Seezo is a work server. |
| 2026-10-31 | MIT licence. | Kartik's call. It's the usual choice for a small public app. |
| 2026-10-31 | Prose comes from *Alice's Adventures in Wonderland* (1865) and *The Time Machine* (1895), checked against Project Gutenberg texts #11 and #35. | All 40 passages trace to the source. Three end early at a colon or semicolon. |
| 2026-10-31 | README images are composed from the real views by `make screenshots`. | No screen capture or permission prompt. The desktop behind the panel is drawn, and the panel's blur isn't rendered. |
