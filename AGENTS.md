# Agent Instructions

When work is complete in this repository:

- Run relevant verification for the changes when feasible.
- Commit the agent's changes with a concise git commit message.
- Push the commit to the current branch's remote when permissions and environment policy allow it.

Additional guidance:

- Do not revert or overwrite unrelated user changes.
- If commit or push fails because approval is required, request approval rather than skipping silently.
- If the work is intentionally incomplete or blocked, do not commit partial work unless the user explicitly asks for it.
- Every committed change should include a version bump in `pubspec.yaml`.
- Keep any in-app version file in sync with `pubspec.yaml`.
- Keep `CHANGELOG.md` updated in the same change.
