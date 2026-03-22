# RFC: Consolidate CI/Build Scripts into buildkite/

## Status
Proposal

## Slack Digest

> **TL;DR: We want to consolidate all CI/build scripts into `buildkite/` as groundwork for splitting CI into a separate repo.**
>
> Today our CI scripts are scattered across `scripts/debian/`, `scripts/docker/`, `scripts/github/`, and `buildkite/scripts/` — they constantly cross-reference each other and the boundary between "CI infra" and "dev tools" is blurry. This blocks the `mina-build` repo split (PR #18579, glyh's feedback: "Could they all reside in folder `buildkite/`?").
>
> **What moves to `buildkite/`:** debian packaging (`build.sh`, `verify.sh`, `publish.sh`, `reversion.sh`), docker building (`build.sh`, `release.sh`, `promote.sh`), github CI triggers, CI-only root scripts (`export-git-env-vars.sh`, linters, coverage).
>
> **What stays in `scripts/`:** dev tools (`testone.sh`, `mina-local-network/`, `benchmarks/`), ops tools (`archive/`), hardfork local testing, `build-go-helper.sh`, `update-opam-switch.sh`.
>
> **Docker strategy:** We have two parallel Docker systems — Dockerfiles (CI, depends on Hetzner/GCR/apt repos) and `nix/docker.nix` (dev, zero infra deps, 111 lines, fully reproducible). Plan is: Nix for dev (`nix build .#mina-image-full | docker load`), Dockerfiles stay as CI/release infra and eventually move with `mina-build`.
>
> **Implementation:** Series of atomic commits moving one directory at a time, updating all cross-references. PR against master.

## Context

The Mina repository has CI-related scripts scattered across three directories:

- `buildkite/scripts/` — CI orchestration, release manager, caching, debian install/publish
- `scripts/` — debian packaging, docker building, hardfork CI, github CI, linting
- `dockerfiles/` — Dockerfiles and entrypoint scripts

These directories are deeply intertwined. For example:
- `buildkite/scripts/release/manager.sh` calls `scripts/debian/verify.sh`, `scripts/docker/promote.sh`
- `scripts/debian/install.sh` sources `buildkite/scripts/cache/manager.sh`
- `buildkite/scripts/build-release.sh` calls `scripts/debian/build.sh`
- `scripts/debian/publish.sh` calls `buildkite/scripts/cache/manager.sh`

This makes it hard to reason about what belongs to CI vs development, creates merge conflicts between CI and app changes, and blocks the eventual split of CI into a separate `mina-build` repository (see [PR #18579](https://github.com/MinaProtocol/mina/pull/18579) and glyh's feedback).

## Two Docker Build Systems

We currently maintain two parallel Docker pipelines:

| | Dockerfile-based (CI) | Nix-based (docker.nix) |
|---|---|---|
| **Images** | 8 Dockerfiles, 3 build stages, ~20 variants | 4 images (slim, full, instr, archive) |
| **Binary source** | Pre-built .deb from apt repos | Built from source via Nix |
| **Reproducibility** | No — depends on apt cache state | Yes — flake.lock pins everything |
| **External deps** | Hetzner, GCR, S3 debian repos, legacy packages | Only nixpkgs + opam-nix |
| **Codename matrix** | bullseye/focal/noble/jammy/bookworm/trixie/questing | None — distro-agnostic |
| **Dev usage** | `docker load` | `nix build .#mina-image-full \| docker load` |

The Nix track (`nix/docker.nix`, 111 lines) builds from source with zero infrastructure dependencies. The Dockerfile track requires Hetzner storage, GCR, local aptly repos, and legacy package pins — purely CI/release infrastructure.

## Proposal

### Phase 1: Consolidate scripts into buildkite/ (this PR)

Move all CI-only scripts from `scripts/` into `buildkite/scripts/`, fixing cross-references.

**Move `scripts/debian/` -> `buildkite/scripts/debian/`** (merge with existing):
- `build.sh`, `builder-helpers.sh` — called only from `buildkite/scripts/build-release.sh`
- `verify.sh`, `verify-inside-docker/` — called only from `buildkite/scripts/release/manager.sh`
- `reversion.sh`, `reversion-helper.sh` — called only from release/manager.sh
- `clear-s3-lockfile.sh` — release pipeline utility
- `aptly.sh` — used by `buildkite/scripts/debian/start_local_repo.sh`
- `tests/` — tests for builder-helpers

**Move `scripts/docker/` -> `buildkite/scripts/docker/`**:
- `build.sh`, `helper.sh` — docker image building, called from Dhall pipeline
- `release.sh`, `promote.sh`, `verify.sh` — called from release/manager.sh
- `setup_buildx.sh` — CI-only buildx setup

**Move `scripts/github/` -> `buildkite/scripts/github/`**:
- `github_info/` — checks PR comments for CI triggers, pure CI

**Move CI-only root scripts -> `buildkite/scripts/`**:
- `export-git-env-vars.sh` — sourced by almost every CI script
- `version-linter.py` — CI lint
- `lint_codeowners.sh`, `lint_rfcs.sh` — CI lint
- `create_coverage_profiles.sh` — CI coverage
- `gsutil-upload.sh` — CI upload
- `link-coredumps.sh` — CI debugging

**What stays in `scripts/`** (development/runtime use):
- `archive/` — ops tooling
- `mina-local-network/` — developer local network
- `tests/` — locally runnable tests
- `hardfork/` — HF config generation, local testing
- `benchmarks/` — performance framework
- `thread-timing/` — developer profiling
- `testone.sh`, `build-go-helper.sh`, `update-opam-switch.sh` — dev tools
- `mina.service` — systemd service
- `pin-external-packages.sh` — used in Dockerfile stage 2

### Phase 2: Move dockerfiles/ into buildkite/ (future PR)

Move `dockerfiles/` -> `buildkite/dockerfiles/` since Dockerfiles are CI packaging infrastructure. `nix/docker.nix` would reference entrypoint scripts via a relative path adjustment.

### Phase 3: mina-build split (future, PR #18579 revisited)

With `buildkite/` self-contained:
- Extract to `mina-build` repo
- All infra deps (Hetzner, GCR, legacy packages, codename matrix) go with it
- `mina` keeps: source, `nix/`, dev scripts
- Post-checkout hook clones `mina-build` and overlays

### For developers: prefer Nix Docker images

```bash
# No CI infrastructure needed:
$(nix build .#mina-image-full) | docker load
$(nix build .#mina-archive-image-full) | docker load
```

## Risks

- Path updates in Dhall files, shell scripts — many references to fix
- Monorepo triage (`buildkite/scripts/monorepo.sh`) dirty-when paths may need updating
- External CI that references old paths (other repos, CI configs)

## Implementation Plan

Phase 1 is implemented as a series of atomic commits:

1. Move `scripts/debian/` into `buildkite/scripts/debian/`
2. Move `scripts/docker/` into `buildkite/scripts/docker/`
3. Move `scripts/github/` into `buildkite/scripts/github/`
4. Move CI-only root scripts into `buildkite/scripts/`
5. Update all Dhall dirty-when paths
