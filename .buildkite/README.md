# `.buildkite/`

This directory bootstraps the CI tooling that lives in
[`MinaProtocol/mina-build`](https://github.com/MinaProtocol/mina-build).

- `_hooks/post-checkout` — Buildkite agent hook that clones `mina-build` and
  overlays it into the workspace at job start. The directory is intentionally
  prefixed with `_` so Buildkite does not auto-discover and execute it yet —
  the hook is staged here while the rollout is gated. Rename to `hooks/` (or
  point `BUILDKITE_HOOKS_PATH` at this directory) to enable.
- `mina-build.version` — pinned ref of `mina-build` to use for this commit.

## `mina-build.version` is a lockfile

The file behaves like `Cargo.lock` / `package-lock.json`:

- **On protected branches** (`master`, `compatible`, `develop`, `release/*`)
  the file **must** contain a 40-character commit SHA. This guarantees that
  re-running CI on an old commit fetches the exact `mina-build` it was
  built against, instead of whatever is at the tip of a branch today.
- **On PR branches** the file may temporarily contain a branch name (e.g.
  `feature-A`) so authors can iterate on `mina-build` without churning
  this repo. Before the PR merges, the branch must be resolved to a SHA.

The `post-checkout` hook enforces the rule on builds whose target is a
protected branch and refuses to bootstrap if the pin is non-SHA. CI runs
the same check explicitly via `scripts/ci/check-mina-build-pin.sh`.

## Bumping the pin

To resolve the current value to a SHA before merging:

```bash
scripts/ci/resolve-mina-build-pin.sh
git add .buildkite/mina-build.version
git commit -m "Pin mina-build to <sha>"
```

The script is idempotent — if the file already holds a SHA, it does nothing.

## Verifying old builds

To find which `mina-build` commit was used to produce a given mina build:

```bash
git show <mina-sha>:.buildkite/mina-build.version
```
