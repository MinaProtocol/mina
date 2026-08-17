# Entrypoints

An entrypoint is the first thing a Buildkite pipeline uploads. It is configured
in the Buildkite UI, outside this repository, so the command each pipeline runs
is written down here.

There are two kinds of build and they do not mix.

**A CI run** decides for itself what to run: it triages a diff against the tags,
the scopes and the dirty-when of every job. Nobody says what to build.

**An artifact build** is started by someone who has said what they want, in a
pull request comment. There is nothing to triage.

Keeping one entrypoint per kind means an ordinary CI run carries none of the
machinery of a selection, and no stray environment variable can turn one into
the other.

| entrypoint | pipelines | what it does |
|---|---|---|
| `../Prepare.dhall` | `mina`, and the nightly and release pipelines | CI. Uploads `Monorepo.dhall`, which triages. |
| `RunSelection.dhall` | `mina-build-docker`, `mina-build-debian`, `mina-build-apps` | Artifacts. Builds what the comment named. |
| `RunSingleJob.dhall` | `mina-single-job` | One named job and its dependencies. |
| `GenerateHardforkPackage.dhall` | the hardfork package pipeline | The hardfork artifacts. |

## The artifact pipelines

All three run the same command, and differ only in the environment the
`ci-build-me` function sets when it starts the build:

```
dhall-to-yaml --quoted <<< "./buildkite/src/Entrypoints/RunSelection.dhall" \
  | buildkite-agent pipeline upload
```

| comment | `BUILDKITE_PIPELINE_LAYER` | `BUILDKITE_PIPELINE_SELECTION` |
|---|---|---|
| `!ci-docker-me` | `docker` | what `set=` said, or `all` |
| `!ci-debian-me` | `debian` | what `set=` said, or `all` |
| `!ci-apps-me` | not used | `build-apps` |

The rest of a comment becomes `BUILDKITE_PIPELINE_CODENAME`, `_ARCH`,
`_NETWORK`, `_PROFILE`, `_INSTRUMENTED`, `_FROM_BUILD` and
`_DEB_SELECTION`. Every one is read by `run-selection.sh` and by nothing else.

None of these values is ever put into a Dhall expression. Dhall can read the
environment, so a value that closed its quote would evaluate on the agent; the
entrypoint therefore takes no argument at all.

The pipelines need no settings of their own. A selection consults no tag, no
scope and no dirty-when, so `BUILDKITE_PIPELINE_FILTER` and its neighbours mean
nothing here.

## Nothing named

`!ci-docker-me` with nothing after it builds every docker image, and
`!ci-debian-me` builds every package. There is no triage to fall back on, and
someone who typed the command asked for a build.
