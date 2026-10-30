# Handoff

The current state only. Replace this page at each checkpoint. Keep it under 40 lines.

**Updated:** 2026-10-30
**Main:** harness only, no app code yet
**Open PRs:** M0, `m0-scaffold`
**Active:** M0 delta review and CI
**Unpushed work:** none

## M0 evidence

Verified in the running app, outside the sandbox, with real key and mouse events:
- `⌃⌥Space` shows the panel at 720 × 136, centred, on the screen under the pointer.
- The frontmost app doesn't change on show, after Esc, or over a full-screen app.
- On a second Space and over a full-screen app, the panel shows with no Space switch.
- Keys go to the panel without activating Twiddle, and Esc hides it.
- A click on another window hides the panel, and focus stays with that window.

## Next steps

1. Merge M0 after review and green CI, then add the `main` ruleset.
2. Build M1.

## Blockers

None.

## Known flakes

None.
