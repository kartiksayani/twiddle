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
| 2026-10-30 | Own settings `NSWindow`. | SwiftUI's `Settings` scene is unreliable in accessory apps. |
| 2026-10-30 | Hints grow the panel upwards and the text moves up. | The board's prototype does this, and 40 pt below the panel can't hold 116 pt. |
| 2026-10-30 | Corpora are written for the project, and prose is pre-1931. | No third-party licences. |
| 2026-10-30 | Ad hoc signing. | Personal app, and no signing identity is installed. |
| 2026-10-30 | Public repo at `github.com/kartiksayani/twiddle`. | Kartik's call. Replaces the local-only plan. |
| 2026-10-30 | `designs/support.js` stays out of the repo. | It's generated Claude Design runtime, and the build doesn't need it. |
| 2026-10-30 | Codex `gpt-6.1-sol` at high effort implements and reviews, in separate threads. Claude architects and merges. | Kartik's call. |
| 2026-10-30 | Delivery follows `ORCHESTRATOR.md`, a tighter version of Ariadne's: PR per milestone, one gate, tables before code, visual evidence, enforced doc limits. | Keeps Ariadne's learnings without its growth. |
| 2026-10-30 | Views live in a separate `TwiddleUI` library. | They can be rendered to PNG in tests, so layout isn't written blind. |
