# Twiddle build prompt

Build Twiddle as described in `SPEC.md`, milestone by milestone. Follow `AGENTS.md`.

Quality comes first, and it's a simple app: the smallest clean solution that meets the spec is the right one.

## Done means

- All milestones M0 to M7 are merged to `main`.
- `make check` passes: build with no warnings, all tests, `swift format lint --strict`.
- `make install` puts a working `Twiddle.app` in `/Applications`.
- Every view matches its section in `designs/Twiddle.dc.html`, in both themes where the board draws both.
- The automated checks below pass, and `CHECKLIST.md` lists whatever needs a person.
- `README.md` covers what Twiddle is, how to build and install it, and how to change the hotkey.
- `HANDOFF.md` is current.

## Real-app checks

Verify these in the running app. If one can't be automated, record it in `CHECKLIST.md` with exact steps.

- Summoning on another Space doesn't switch Spaces.
- Summoning over a full-screen app shows the panel on top of it.
- The frontmost app is unchanged while the panel is open, and it keeps focus after a dismiss.
- Audio keeps playing through summon, typing and dismiss.
- Clicking another window hides the panel and the click lands in that window.
- Flow resumes at the start of the unfinished word, per source, including after a relaunch.
- No permission prompt appears at any point.
- The hotkey works after launching at login.
- A taken shortcut shows the conflict state.
