# Delivery

How Twiddle gets built. This file is the only source for roles and process. Keep it under 100 lines. Grow it only under the process budget below.

## Roles

| Role | Who | Does |
|---|---|---|
| Maintainer | Claude Code, main session | Owns the spec, writes briefs, adjudicates reviews, checks visuals, pushes, merges. |
| Implementer | Codex `gpt-6.1-sol`, high effort, `--write` | Builds one brief on its branch. Doesn't push or merge. |
| Reviewer | Codex `gpt-6.1-sol`, high effort, fresh read-only thread | Reviews an exact commit. Never shares a thread with the implementer. |
| Owner | Kartik | Approves the spec and any change to it. Runs what `CHECKLIST.md` lists. |

Dispatch through the `codex:codex-rescue` agent with `--model gpt-6.1-sol --effort high --fresh`. Add `--write` for implementers only. Name agents `sol-high-<milestone>-<role>`.

## The milestone loop

1. **Brief.** Write the goal, spec sections, settled decisions, owned paths, tests required, and what done means. Add the tables below if they apply.
2. **Build.** Codex works on `m<N>-<name>`, runs `make check`, and reports real output.
3. **Verify.** The maintainer runs `make check` again and reads the diff. UI milestones also get the visual check.
4. **Open a PR.** Its body states what changed and how each claim was verified: test, snapshot, real app, or not verified.
5. **Review.** A fresh reviewer checks the exact head SHA against the spec.
6. **Adjudicate.** The maintainer accepts or rejects each finding, with a reason. Accepted fixes go back to the implementer.
7. **Re-review.** One delta review of the fix commits against the reviewed head. Expand it to the whole flow if behaviour or invariants changed.
8. **Merge.** Run `/simplify` before the final code commit. Then `gh pr merge --squash --match-head-commit <sha>`, once CI is green on that SHA. Confirm `main` matches the PR head's tree.
9. **Handoff.** Rewrite `HANDOFF.md`.

## Gates

- `make check` is the only gate, and CI runs the same command. No check exists in only one place.
- CI stays under 10 minutes.
- The pre-commit hook stays cheap: identity, public-repo safety, and format on staged files.
- Coverage covers `TwiddleCore` only, with a single threshold and no exclusion list.
- A failing required check that passed before gets one rerun. If it passes, log the flake in `HANDOFF.md`. A second occurrence gets fixed before the next merge.

## Review standard

- Every review names its exact head SHA and scope. A new head needs a new review.
- **Affected flow:** follow changed behaviour from entry point through state changes and effects to completion and errors, including unchanged code that shares the state.
- Also check spec compliance, test quality, scope creep and needless complexity.
- Zero findings is a valid result. Findings need a file, line and failure scenario.

## Write the table before the code

Ariadne wrote these only after repeated failed fixes. Twiddle writes them into the brief up front.

- **Failure table:** for storage and error handling, cross every error source with every operation, and state the outcome for each pair. One test per row. Required for `Store`.
- **Interaction table:** for state that responds to several triggers, cross states with events. One test per row. Required for `PracticeModel` and panel show, hide and focus.
- Reviewers check tables for missing rows as well as checking the diff.
- A third fix round in one area stops. The maintainer re-briefs from the table.

## Visual work

Nobody writes layout blind.

- Views live in `TwiddleUI`, and they render from fixture state to PNG with `make snapshots`.
- Each board section gets a reference PNG in `designs/reference/`.
- The maintainer compares snapshots against references and sends back specific differences, in points.
- Tests assert values from the app's own state, never guessed display text.

## Rules that stay

- **Test boundary:** test Twiddle's behaviour, not Apple's window mechanics. Real-app checks prove our wiring once, and they aren't a repeated gate.
- **Pin before moving:** before moving or sharing UI or state code, pin every control it touches with tests that pass before and after.
- **Saved formats:** a change to `state.json` keeps a test that reads the previous version. Otherwise the PR states the one-way step and the owner approves it.
- **Tooling blockers:** one attempt of about 15 minutes, then report the cost and a cheaper route.
- **Scope:** new ideas go in the PR as a note, not in the code. `SPEC.md` changes need the owner.

## Process budget

- No new process or tooling until the same problem has happened twice. Record both occurrences and the expected saving.
- No receipts. The PR is the record.
- `HANDOFF.md` is one page and gets replaced, never appended.
- Line limits are enforced by `make check`.
