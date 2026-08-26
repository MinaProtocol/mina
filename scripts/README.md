# scripts/

Developer and CI scripts, grouped by what they are for. A script belongs in the
directory that describes **why it is run**, not which component it touches.

| Directory | Contents |
| --- | --- |
| `build/` | Preparing a build environment: the opam switch, pinned external packages, the Go helper build. |
| `lint/` | Repository lint gates, one per CI lint step: CODEOWNERS, RFCs, ppx versions, submodule pins, versioned types. |
| `tests/` | Test runners and the regeneration of test fixtures. `tests/rosetta/` holds the Rosetta suites. |
| `genesis/` | Generating and publishing genesis ledgers and configs. |
| `hardfork/` | The hard-fork process: runtime config, package conversion, dry-run ledgers, local fork networks. |
| `debian/` | Building the `.deb` packages, plus assets they ship (`mina.service`). |
| `docker/` | Building and tagging docker images. |
| `archive/` | Operating an archive node (block backfill). |
| `rocksdb/` | Converting the daemon's RocksDB storage between formats. |
| `verify/` | Post-install checks that a packaged binary runs. |
| `ci/` | Resolving and checking the pinned mina build used by CI. |
| `github/` | Talking to the GitHub API. |
| `mina-local-network/` | Running a multi-node network on one machine. |
| `thread-timing/` | Plotting daemon thread traces. |

`export-git-env-vars.sh` stays at the top level: it derives the version, branch
and commit identity that nearly every other script and CI step sources, so it
belongs to no single group.

CI-only scripts live under `buildkite/scripts/`, not here. This directory is for
scripts a developer can also run locally.

## Adding a script

Put it in the directory matching its purpose, and reference it by its full path
from the repository root. Buildkite job definitions select work from these paths
(`buildkite/src/**/*.dhall`, `dirtyWhen`), so a script that moves without its
`dirtyWhen` entry silently stops triggering the job that runs it.
