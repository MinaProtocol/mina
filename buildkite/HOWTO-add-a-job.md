# HOWTO: Add a new Buildkite job

This is the contributor onboarding guide for adding a CI job to the Mina
buildkite pipeline. It complements (and does not duplicate) two existing
references:

- [`buildkite/src/README.md`](./src/README.md) — system overview: pipeline
  modes, stages, filters, entrypoints (`Prepare.dhall`, `Monorepo.dhall`).
  Read first if you don't yet know what a "stage" is.
- [`buildkite/local/README.md`](./local/README.md) — how to run a job
  locally without pushing to CI. Read **before** you push your change.

Read this file when you want to: copy an existing job to make a new one,
understand `JobSpec` and `dirtyWhen`, understand the
`Constants/{Artifacts,DebianPackage,Profiles,Network,DockerVersions}.dhall`
relationship, or sanity-check that your new job will actually be selected
by the triage script.

---

## TL;DR — add a new test job in 5 steps

Say you want a new test that runs a shell script under
`buildkite/scripts/my-new-test.sh`.

1. **Copy a similar existing job.** A small, self-contained example to
   start from is
   [`buildkite/src/Jobs/Test/ConnectToDevnet.dhall`](./src/Jobs/Test/ConnectToDevnet.dhall) —
   30 lines, single step, no Release-side complications.

2. **Edit the copy.** At minimum:
   - `name` — must be unique across all jobs. The `check_dups` make target
     enforces this.
   - `path` — `Test`, `Release`, `Lint`, or `Bench`. Must match the
     subdirectory under `buildkite/src/Jobs/`.
   - `dirtyWhen` — see [§ dirtyWhen DSL](#dirtywhen-dsl) below.
   - `tags` — see [§ Tags & scopes](#tags--scopes).
   - `steps` — at least one [Command step](#commands).

3. **Run validation locally:**
   ```bash
   cd buildkite && make all
   ```
   This runs `check_syntax`, `lint`, `format`, `check_deps`, `check_dirty`,
   `check_dups`, `check_names`, and `test_monorepo`. CI will run the same
   set, so don't push without passing it.
   ([`buildkite/Makefile:85-88`](./Makefile))

4. **Dry-run the job locally** before pushing:
   ```bash
   ./buildkite/local/run_job.sh --dry-run MyNewJob
   ```
   See [`buildkite/local/README.md`](./local/README.md) for the one-time
   setup (`/var/storagebox`, `/var/buildkite/shared`).

5. **Push.** The triage script picks the job up automatically — there is
   no central registry to edit. (More details:
   [§ Triage / how the job gets picked up](#triage--how-the-job-gets-picked-up).)

---

## Anatomy of a job

Every job is a single `Pipeline.build` call producing a Buildkite YAML
steps array. Schema:
[`buildkite/src/Pipeline/Dsl.dhall:16-52`](./src/Pipeline/Dsl.dhall).

```dhall
in  Pipeline.build
      Pipeline.Config::{
      , spec  = JobSpec::{ … }    -- metadata: how/when this job runs
      , steps = [ … ]              -- list of Command.Type
      }
```

### `JobSpec` fields

Defined at [`buildkite/src/Pipeline/JobSpec.dhall:9-25`](./src/Pipeline/JobSpec.dhall).

| Field        | Type                       | Default          | What it controls |
|---|---|---|---|
| `path`       | `Text`                     | `"."`            | Directory under `buildkite/src/Jobs/` (`"Test"`, `"Release"`, `"Lint"`, `"Bench"`). Used to compute the Buildkite step key. |
| `name`       | `Text`                     | *(required)*     | Globally unique job name. `check_dups` enforces uniqueness. |
| `scope`      | `List Scope.Type`          | `Scope.Full`     | Which top-level run scopes (PullRequest / Nightly / MainlineNightly / Release) include this job. |
| `tags`       | `List PipelineTag.Type`    | `[Fast]`         | Filter labels. `BUILDKITE_PIPELINE_FILTER` selects by tag. |
| `dirtyWhen`  | `List SelectFiles.Type`    | *(required)*     | Egrep patterns. In `PullRequest` mode the job runs only if at least one pattern matches `git diff`. |
| `excludeIf`  | `List Expr.Type`           | `[]`             | Branch-ancestor predicates that exclude this job from a run. |
| `includeIf`  | `List Expr.Type`           | `[]`             | Branch-ancestor predicates that *force-include* this job. |

Use `JobSpec::{ name = "…", … }` syntax — the Dhall record-update form
fills in defaults for fields you omit.

### `Scope.Type` and `Tag.Type`

- **Scope** — 4 values: `PullRequest`, `Nightly`, `MainlineNightly`,
  `Release`. Source:
  [`buildkite/src/Pipeline/Scope.dhall:17`](./src/Pipeline/Scope.dhall).
  Useful constants: `Scope.Full` (all four), `Scope.PullRequestOnly`,
  `Scope.AllButPullRequest`.
- **Tag** — ~25 values such as `Fast`, `Long`, `VeryLong`, `Test`,
  `Release`, `Lint`, `Docker`, `Debian`, `Hardfork`, `Rosetta`, `Devnet`,
  `Mainnet`, `Bullseye`, `Bookworm`, `Noble`, `Focal`, `Jammy`, `Arm64`,
  `Amd64`, `Mesa`. Source:
  [`buildkite/src/Pipeline/Tag.dhall:11-37`](./src/Pipeline/Tag.dhall).
  Pick the smallest set that's still descriptive — tags drive
  `BUILDKITE_PIPELINE_FILTER` and the make-target `check_*` linters.

### Commands

Each entry of `steps` is a `Command.Type` value. For a simple shell-script
job, use `Command.build` directly; for opinionated test/release commands
there are pre-built helpers under
[`buildkite/src/Command/`](./src/Command/) (e.g.
`Command/ConnectToNetwork.dhall`, `Command/ChainIdTest.dhall`,
`Command/MinaArtifact.dhall`). Prefer reusing a helper when one exists.

---

## `dirtyWhen` DSL

`dirtyWhen` is the **monorepo triage signal**: in `PullRequest` mode the
pipeline runs the job only if `git diff` against the merge base touches a
file that matches one of its patterns.

The DSL is defined at
[`buildkite/src/Lib/SelectFiles.dhall:6-166`](./src/Lib/SelectFiles.dhall).
Patterns compile to egrep regexes consumed by
[`buildkite/scripts/monorepo.sh:335-343`](./scripts/monorepo.sh).

Common building blocks (typically aliased as `S`):

```dhall
let S = ../../Lib/SelectFiles.dhall

-- Anything under src/ (anchored at the start of the path)
S.strictlyStart (S.contains "src")

-- Exact file: buildkite/scripts/connect/connect-to-network.sh
S.exactly "buildkite/scripts/connect/connect-to-network" "sh"

-- This job's own dhall file (always include this!)
S.exactly "buildkite/src/Jobs/Test/MyNewJob" "dhall"
```

**Always include the job's own file.** If you forget, edits to the job
itself won't trigger a run, which makes iteration painful.

The `make check_dirty` target validates that every pattern still matches
real files in the repo, so a typo in a path is caught before you push
([`buildkite/Makefile:68-71`](./Makefile)).

---

## `Constants/*.dhall` cheatsheet

Most jobs are parameterized over a small handful of orthogonal axes.
Understanding which Constants module owns which axis stops you from
hand-rolling strings.

| Module | What it enumerates | Where to import from |
|---|---|---|
| `Constants/Artifacts.dhall` | Build targets (Daemon, Archive, Rosetta, …) and their Docker/Debian naming | [`buildkite/src/Constants/Artifacts.dhall`](./src/Constants/Artifacts.dhall) |
| `Constants/DebianPackage.dhall` | Subset of artifacts that ship as `.deb` packages | [`buildkite/src/Constants/DebianPackage.dhall`](./src/Constants/DebianPackage.dhall) |
| `Constants/Profiles.dhall` | Build profiles: `Devnet`, `Mainnet`, `Lightnet`, `Dev` | [`buildkite/src/Constants/Profiles.dhall`](./src/Constants/Profiles.dhall) |
| `Constants/Network.dhall` | Networks: `Devnet`, `Mainnet`, … | [`buildkite/src/Constants/Network.dhall`](./src/Constants/Network.dhall) |
| `Constants/DockerVersions.dhall` | Debian codenames the daemon image is built for: `Bullseye`, `Bookworm`, `Jammy`, `Focal`, `Noble`. Also the `dependsOn` helper. | [`buildkite/src/Constants/DockerVersions.dhall`](./src/Constants/DockerVersions.dhall) |
| `Constants/DebianVersions.dhall` | Bridge between codenames and Debian versions. | [`buildkite/src/Constants/DebianVersions.dhall`](./src/Constants/DebianVersions.dhall) |

Relationships at a glance:

- An **Artifact** is the build target (e.g. `Daemon`, `Archive`).
- Artifacts that produce a `.deb` are also a **DebianPackage**. (Things
  like `Toolchain` and `DaemonPrefork` are Artifacts but **not**
  DebianPackages.)
- A **Profile** parameterizes how the Artifact is built (mainnet vs
  devnet vs lightnet vs dev).
- A **Network** is the runtime network the binary connects to.
  `Profiles.fromNetwork` projects a Network onto a Profile when needed.
- A **Codename** (DockerVersions.Docker) selects the Debian base image
  for the build.

The fully-qualified job-name convention is
`<Prefix><Codename><Network><Profile>[<BuildFlags>][<Arch>]`, e.g.
`MinaArtifactBookwormDevnetDevnet`,
`MinaArtifactNobleDevnetLightnetArm64`. The `dependsOn` helper at
[`buildkite/src/Constants/DockerVersions.dhall`](./src/Constants/DockerVersions.dhall)
generates these names so other jobs can declare them as upstream
dependencies without hand-typing.

---

## Tags & scopes

`tags` filter what's *eligible* to run; `scope` decides *when* (in which
top-level run mode) the job is eligible at all.

Mental model:

```
PullRequest run? → check Scope                      (gate 1)
                 → check tags vs PIPELINE_FILTER    (gate 2)
                 → in PR mode also: check dirtyWhen (gate 3)
```

Heuristics for picking tags:

- Always include exactly one of `Fast` / `Long` / `VeryLong` so
  `BUILDKITE_PIPELINE_FILTER=FastOnly` can shed the slow ones in PR runs.
- Add a category tag: `Test`, `Release`, `Lint`, `Bench`.
- Add the matrix axis tags that apply: `Devnet`/`Mainnet`,
  `Bullseye`/`Bookworm`/…, `Amd64`/`Arm64`. The lint targets
  cross-validate that names match the tag set.

---

## Triage / how the job gets picked up

There is **no central registry** of jobs. `Prepare.dhall` walks the
filesystem under `buildkite/src/Jobs/{Test,Release,Lint,Bench}/` and
includes everything it finds. Adding a job means adding a file; deleting
a job means deleting a file.

The triage script [`buildkite/scripts/monorepo.sh`](./scripts/monorepo.sh)
then reads `BUILDKITE_PIPELINE_MODE`:

- `Stable` — emits every job whose tags & scope match the filter.
- `PullRequest` — additionally checks each job's `dirtyWhen` patterns
  against `git diff` and drops jobs that don't match.

This is why `dirtyWhen` is required: in PR mode, an unmatched job is
silently skipped. To debug a job that you expect to run but doesn't,
start by re-reading its `dirtyWhen`.

---

## Validation: `cd buildkite && make all`

Mandatory before pushing. Targets and what each catches:

| Target | What it catches |
|---|---|
| `check_syntax` | Broken Dhall (parse errors, missing imports). |
| `check_lint` / `lint` | Style violations (`dhall lint --check`). |
| `check_format` / `format` | Formatting drift (`dhall format --check`). |
| `check_deps` | A job declares a `dependsOn` that names a job that doesn't exist. |
| `check_dirty` | A `dirtyWhen` pattern points at a path that has no real file behind it. |
| `check_dups` | Two jobs share the same `name`. |
| `check_names` | Job name doesn't match its filename / tag set. |
| `test_monorepo` | Triage logic regression tests (see [`scripts/test_monorepo.sh`](./scripts/test_monorepo.sh)). |

Each target is also runnable on its own — useful when you're iterating
on a single concern.

---

## Local testing — run the job before pushing

The full `./buildkite/local/run_job.sh` runner is documented in
[`buildkite/local/README.md`](./local/README.md). Workflow summary:

```bash
# One-time host setup
sudo mkdir -p /var/storagebox /var/buildkite/shared
sudo chown $(id -u):$(id -g) /var/storagebox /var/buildkite/shared

# What jobs exist?
./buildkite/local/run_job.sh --list

# Preview the commands a job would run, without executing
./buildkite/local/run_job.sh --dry-run MyNewJob

# Run end-to-end against a local Docker setup
./buildkite/local/run_job.sh MyNewJob

# Run only one step of a job
./buildkite/local/run_job.sh --step "step-key" MyNewJob

# Run with overridden env (e.g. NETWORK, VERSION, CODENAMES)
./buildkite/local/run_job.sh --env-file ./my-env.txt MyNewJob
```

The runner generates the pipeline YAML via `dhall-to-yaml`, so any
typo or schema mismatch in your `.dhall` shows up here without
round-tripping through CI.

Requirements: `yq`, `dhall-to-yaml`, `docker`, `rsync`, port `8080`
free. Full prerequisites and cache-population details are in
[`buildkite/local/README.md`](./local/README.md).

---

## Common pitfalls

- **Forgot to include the job's own `.dhall` file in `dirtyWhen`.** Edits
  to the job won't re-trigger it. Always include
  `S.exactly "buildkite/src/Jobs/<Path>/<Name>" "dhall"`.
- **Job runs in `Stable` but never in `PullRequest`.** Almost always a
  `dirtyWhen` mismatch. Run `make check_dirty` and inspect the regex.
- **`check_deps` fails after you delete a job.** Some other job had a
  `dependsOn` pointing at it. Either re-add the dependency or update the
  caller. The DockerVersions `dependsOn` builder is name-based, not
  type-checked, so this is the usual culprit.
- **Job name collisions.** Two jobs named `MinaArtifactNobleDevnetDevnet`
  are silently fatal in CI. `check_dups` exists to catch this — run it.
- **Profile vs Network vs codename confusion.** Profile = how it's built
  (`Devnet`/`Mainnet`/`Lightnet`/`Dev`); Network = what it connects to;
  Codename = which Debian base image. Don't reach for a string when a
  Constants enum exists.
- **Using `Pipeline.build` without `Pipeline.Config::{ … }`.** The
  build entry expects a Config record; pass it with the record-update
  syntax so defaults flow through.
