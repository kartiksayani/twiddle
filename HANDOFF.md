# Handoff

The current state only. Replace this page at each checkpoint. Keep it under 40 lines.

**Updated:** 2026-10-30
**Main:** harness only, no app code yet
**Open PRs:** M0, `m0-scaffold`
**Active:** M0 review
**Unpushed work:** none

## M0 evidence

Verified in the running app, outside the sandbox:
- `⌃⌥Space` shows the panel at 720 × 136, centred, on the screen under the pointer.
- The frontmost app doesn't change on show or after Esc.
- Esc hides the panel, so it receives keys without activating.
- On a second Space, the panel shows without a Space switch.

Not verified: full-screen app, click-away and click-through.

## Next steps

1. Owner or maintainer runs the full-screen check. It blocks M3, not M1 or M2.
2. Merge M0 after review and green CI, then add the `main` ruleset.
3. Build M1.

## Blockers

None.

## Known flakes

None.
