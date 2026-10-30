# Twiddle agent rules

Read `SPEC.md` and `HANDOFF.md` first. `ORCHESTRATOR.md` is the process.

## Scope

- Build only what `SPEC.md` and the board describe. If something seems missing, ask; don't add it.
- Don't add dependencies.
- Don't change a decision in `DECISIONS.md`. Raise it instead.
- `SPEC.md` wins on data and behaviour. `designs/` wins on look and feel.

## Code

- Keep `TwiddleCore` free of AppKit and SwiftUI. Inject time and randomness.
- `PracticeModel` is the only owner of practice state.
- Don't add protocols, abstractions or configuration for a single use.
- Don't catch errors just to ignore them. Don't add `TODO`s, dead code or commented-out code.
- Comments explain why, and only where the code can't.
- Use design tokens from `Theme.swift`. Don't hardcode colours or sizes in views.
- Remove whatever your change leaves unused.

## Testing

- Add tests with every behaviour change in `TwiddleCore`.
- Run `make check` before reporting. Report real output. If something failed or was skipped, say so.
- For UI work, run the real app and state what you actually verified.

## Git

- Work on the milestone branch you are given, and leave your work uncommitted.
- Don't push. The maintainer commits, pushes and merges.
- The repo is public. Never commit secrets, personal data or machine-specific paths.
