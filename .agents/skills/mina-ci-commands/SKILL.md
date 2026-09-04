---
name: mina-ci-commands
description: Use when the user asks to trigger Mina CI, Buildkite CI, PR CI, rerun a failed Mina build, run one Buildkite job, or rebuild the shared base/toolchain docker images — !ci-build-me, !ci-single-me, !ci-docker-me, !ci-docker-base-me, !ci-toolchain-me, !ci-debian-me, !ci-artifacts-me, !ci-nightly-me, !ci-nix-me, !approved-for-mainnet — and when a posted !ci-* comment produced no build, or a build looks failed but its artifact may be fine. Also covers casual phrasings: "kick off CI on that PR", "republish mina-base", "why did nothing start", "add the ci-build-me label". Use this skill to choose the right magic comment and post it with gh CLI on Mina PRs instead of guessing command syntax.
---

# Mina CI Commands

Use this skill when working in or against `MinaProtocol/mina` and the user asks to trigger CI, rerun Buildkite, run a specific job, build docker/debian/toolchain artifacts, run nightly CI, or post a `!ci-*` PR comment.

The Mina repo uses GitHub PR comments as CI control commands. Prefer `gh` CLI; do not invent syntax. If the target PR or job/filter is ambiguous, ask one focused question before commenting.

## Post a comment — never add a label

Trigger CI by creating an **issue comment**; do not use `gh pr edit --add-label`. Every handler in `frontend/ci-build-me/src/index.js` gates on `issue_comment.created` — there is no label handler. A label named after a command does not exist in the repo, so `gh` creates it, leaving junk on the org's label list and starting no build.

## Safety checks before posting

1. Identify the PR number or URL.
2. Confirm the repository is `MinaProtocol/mina` unless the user explicitly gives another repo.
3. If the requested command is broad or expensive (`!ci-build-me`, `!ci-nightly-me`, broad `!ci-docker-me`), proceed if the user clearly requested it; otherwise ask confirmation.
4. Post the command as the entire comment body. Any explanation belongs in a separate comment — see "Comment must match exactly, or by prefix".
5. Check the comment shape against "Comment must match exactly, or by prefix" — an exact-match command with any extra prose attached is dropped without a word.
6. For PR-build commands (`!ci-build-me`, `!ci-nightly-me`, `!ci-docker-me`), check the PR is cleanly mergeable first. Triggers fired in the brief `UNKNOWN` window right after a push have been observed to produce nothing. Poll command in "Troubleshooting: the trigger produced no build".
7. After posting, return the GitHub comment URL and the exact command body, and stop. Do not poll Buildkite for the build to appear — see "Attach the Buildkite build URL as a follow-up comment" for the one non-blocking query that is worth making.

Useful PR extraction:

```bash
# From a PR URL
pr=19061

# Or from current branch if inside the Mina checkout
gh pr view --repo MinaProtocol/mina --json number,url,headRefName,baseRefName
```

Post a comment:

```bash
gh api repos/MinaProtocol/mina/issues/$pr/comments \
  -f body='!ci-build-me' \
  --jq '.html_url'
```

For multiline comments, use `-F body=/path/to/body.txt`.

## Comment must match exactly, or by prefix

Each handler in `frontend/ci-build-me/src/index.js` tests the **whole comment body**. Two shapes exist, and mixing them up is the quietest way to get no build at all:

- **Exact (`==`)** — the comment must be *nothing but* the command: `!ci-build-me`, `!ci-nightly-me`, `!ci-nix-me`, `!ci-debian-me`, `!ci-toolchain-me`, `!ci-docker-base-me`, `!approved-for-mainnet`. A trailing "rebuilding the base images because X" makes the handler skip it silently.
- **Prefix (`startsWith`)** — arguments allowed: `!ci-single-me`, `!ci-docker-me`, `!ci-artifacts-me`.

Check which shape a command has before adding any prose to the comment:

```bash
grep -n 'comment.body ==\|comment.body.startsWith' frontend/ci-build-me/src/index.js
```

`!ci-docker-base-me` is deliberately handled *above* the `!ci-docker-me` prefix branch, since it shares that prefix.

## Commands handled by `frontend/ci-build-me`

These commands are handled by the Mina `frontend/ci-build-me` webhook on `issue_comment.created` for PRs. Every one of them requires the comment author be a **public** member of the `MinaProtocol` GitHub org.

| Command | Buildkite pipeline | Use when |
|---|---|---|
| `!ci-build-me` | `mina-o-1-labs` | Normal broad PR CI / rerun standard CI. |
| `!ci-nightly-me` | `mina-end-to-end-nightlies` | Nightly/end-to-end checks. Heavier than normal CI. |
| `!ci-nix-me` | `mina-nix-experimental` | Nix experimental pipeline. |
| `!ci-debian-me` | `mina-build-debian` | Debian package build pipeline. |
| `!ci-docker-me` | `mina-build-docker` | Docker image build pipeline; may be filtered. |
| `!ci-toolchain-me` | `mina-toolchains-build` | Rebuild the opam toolchain images (tag `Toolchain`). Takes hours. Does **not** touch the `mina-base` images. |
| `!ci-docker-base-me` | `mina-docker-base-build` | Rebuild the shared `mina-base` images (tag `Base`) for all codenames. Use after changing `dockerfiles/stages/1-base-deps`, or to publish/refresh the `minaBase*` pins. |
| `!ci-single-me <JobName>` | `mina-single-job` | Run one generated job and its dependencies. Passed as `JOB_NAME`. |
| `!ci-artifacts-me <layer> [k=v]` | `mina-artifacts` | Build a named artifact layer (`docker`/`debian`/`apps`) with no triage. `develop` only — its entrypoint exists on no other branch. |
| `!approved-for-mainnet` | `mina-pr-gating` | Mainnet approval/gating command; restricted to specific approvers. |

Examples:

```bash
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-build-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-nightly-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-debian-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-toolchain-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-docker-base-me' --jq '.html_url'
```

## `!ci-docker-base-me`

Rebuilds the shared `mina-base` images — debian-slim plus the common apt deps and the gcloud SDK, the layer the daemon/archive/hardfork images are built `FROM`. Use it after changing `dockerfiles/stages/1-base-deps`, or to publish a fresh set for the `minaBase*` pins.

Takes no arguments, and the comment body must be exactly `!ci-docker-base-me`. It triggers `mina-docker-base-build` with:

```text
BUILDKITE_PIPELINE_FILTER=BaseDockersOnly
BUILDKITE_PIPELINE_JOB_SELECTION=Full
```

`BaseDockersOnly` maps to the `Base` tag (`buildkite/src/Pipeline/TagFilter.dhall`), which only the `MinaBaseArtifact*` jobs carry, so the opam toolchain images are excluded — `!ci-toolchain-me` and this command rebuild disjoint image sets, and bumping one is never a reason to bump the other. `Full` skips dirty-when triage, so the rebuild runs even when the PR touched nothing under `dockerfiles/stages/1-base-deps`, which is the whole point of an on-demand rebuild.

This is the **only** way these jobs run: they carry neither `Fast` nor `Long`, so the standard PR/nightly pipeline stages (`FastOnly`, `LongAndVeryLong`, `TearDownOnly`) filter them out regardless of `dirtyWhen`.

One run builds every job under `buildkite/src/Jobs/Release/MinaBaseArtifact*.dhall` — currently Bullseye, Bookworm, BookwormArm64, Focal, Jammy, Noble. Confirm the current set rather than trusting this list:

```bash
ls buildkite/src/Jobs/Release/MinaBaseArtifact*.dhall
```

Each job pushes `docker.io/minaprotocol/mina-base:<githash>-<codename>-<network>` (the `network` segment is `devnet` for these specs; arm64 adds an `-arm64` suffix) and writes `${CACHE_ROOT}/mina-base/<tag>.tar.zst` under `/var/storagebox/docker-cache`.

### After it finishes: bump the pins

The build is only half the job. Verify the image is actually published, then bump the `minaBase*` entries in `buildkite/src/Constants/ContainerImages.dhall` to the new short githash — all of them land on one hash:

```bash
tok=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:minaprotocol/mina-base:pull" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $tok" \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
  "https://registry-1.docker.io/v2/minaprotocol/mina-base/manifests/<7charsha>-bullseye-devnet"   # 200 = published
```

A stale or unpublished pin is not fatal — `scripts/docker/build.sh` falls back to inlining the base-deps stage when the image is not in the CI cache — so the only cost of forgetting the bump is losing the reuse, which shows up as slower builds rather than a failure. That silence is why the bump is easy to skip; do it in the same PR.

## `!ci-docker-me` filters

Current `ci-build-me` parsing accepts only whitespace-separated `key=value` arguments. Only these keys affect the Buildkite env:

- `arch`: `amd64`, `arm64`
- `profile`: `devnet`, `lightnet`, `mainnet`
- `codename`: `jammy`, `noble`, `bullseye`, `focal`, `bookworm`

When all three are present and valid, the handler sets:

```text
BUILDKITE_PIPELINE_FILTER=DockerBuild<Arch><Profile><Codename>
BUILDKITE_PIPELINE_FILTER_MODE=All
```

Example:

```text
!ci-docker-me arch=amd64 profile=devnet codename=bookworm
```

maps to:

```text
DockerBuildAmd64DevnetBookworm
```

Post it:

```bash
gh api repos/MinaProtocol/mina/issues/$pr/comments \
  -f body='!ci-docker-me arch=amd64 profile=devnet codename=bookworm' \
  --jq '.html_url'
```

Partial keys are kept, not discarded: `arch=amd64` alone yields the real filter `DockerBuildAmd64`. Only a bare `!ci-docker-me` with none of the three keys falls back to the broad filter:

```text
BUILDKITE_PIPELINE_FILTER=DockerBuild
```

An *invalid* value is silently dropped from the filter rather than rejected, so `codename=trixie` quietly widens the build instead of failing. Check spellings against the lists above.

Do not use old examples like `network=testnet-generic`; the current handler ignores that key.

## `!ci-single-me <JobName>`

Handled by `frontend/ci-build-me` as a **prefix** command: the job name is the last whitespace-separated word of the comment, checked against an allow-list of characters in `src/safe-input.js`, then passed to the `mina-single-job` pipeline as `JOB_NAME`. That pipeline runs `buildkite/scripts/run-single-job-with-deps.sh`.

Use it to trigger one generated Buildkite job and its dependencies:

```text
!ci-single-me HardForkTestMixed
```

Post it:

```bash
gh api repos/MinaProtocol/mina/issues/$pr/comments \
  -f body='!ci-single-me HardForkTestMixed' \
  --jq '.html_url'
```

Matching behavior from `buildkite/scripts/run-single-job-with-deps.sh`:

- Case-insensitive.
- Full-string exact match against generated YAML `spec.name`.
- Falls back to filename stem if `spec.name` is absent.
- No substring matching.
- No aliases found.

Good:

```text
!ci-single-me HardForkTestMixed
!ci-single-me TestnetIntegrationTests
!ci-single-me TestnetIntegrationTestsLocalApps
```

Likely bad:

```text
!ci-single-me HardFork
!ci-single-me Testnet
```

### Known job-name families

The effective names come from generated Buildkite YAML under `buildkite/src/gen/`, created from Dhall. If accuracy matters, inspect or regenerate the current job list before posting.

Previously observed examples include:

- Test: `HardForkTestMixed`, `HardForkTestLegacy`, `TestnetIntegrationTests`, `TestnetIntegrationTestsLocalApps`, `TestnetIntegrationTestsLong`, `SingleNodeTest`, `RosettaIntegrationTests`, `ArchiveNodeTest`, `DaemonUnitTest`, `Libp2pUnitTest`, `ZkappsExamplesTest`, `MonorepoTest`, `NixBuildTest`, `VersionLint`.
- Lint: `OCaml`, `Rust`, `Dhall`, `Docker`, `Bash`, `Changelog`, `Fast`, `Merge`, `Xrefcheck`, `ArchiveUpgrade`.
- Bench: `ArchiveStable`, `ArchiveUnstable`, `HeapUsageStable`, `HeapUsageUnstable`, `LedgerApplyStable`, `LedgerApplyUnstable`, `MinaBaseStable`, `MinaBaseUnstable`, `SnarkProfilerStable`, `SnarkProfilerUnstable`, `ZkappLimitsStable`, `ZkappLimitsUnstable`.
- Release: `MinaArtifactBookworm`, `MinaArtifactBookwormArm64`, `MinaArtifactBullseye`, `MinaArtifactBullseyeApps`, `MinaArtifactBullseyeInstrumented`, `MinaArtifactMainnetBullseye`, `MinaArtifactNoble`, `MinaToolchainArtifactBookworm`, `MinaToolchainArtifactNoble`, `Minimina`, `TraceTool`.
- TearDown: `Coverage`.

Release names are especially dynamic because they are derived from Dhall constants such as network, Debian codename, build flags, and architecture.

## Discover current job names

When the user asks for a specific `!ci-single-me` job and the exact name is uncertain, inspect the repo instead of guessing.

Useful files:

- `buildkite/scripts/run-single-job-with-deps.sh`
- `buildkite/src/Jobs/`
- `buildkite/src/gen/` if present/generated
- `buildkite/HOWTO-add-a-job.md`

Fast checks:

```bash
# Search source job definitions by likely name fragment
rg 'HardForkTestMixed|TestnetIntegrationTests|spec.name|name =' buildkite/src buildkite/scripts

# If generated YAML exists, inspect effective spec names
rg '^\s*name:|spec:' buildkite/src/gen buildkite -g '*.yml' -g '*.yaml'
```

If a generated list is unavailable and the job name matters, run or inspect the repo's Dhall generation path before posting.

## Survey existing usage

Use GitHub search when you need examples from past PRs:

```bash
gh api -X GET search/issues \
  -f q='repo:MinaProtocol/mina is:pr !ci-docker-me in:comments' \
  -f per_page=30 \
  --jq '.items[] | {number,title,url,updated_at}'
```

Fetch matching comments for specific PRs:

```bash
for pr in 19061 18638; do
  gh api "repos/MinaProtocol/mina/issues/$pr/comments" --paginate \
    --jq ".[] | select(.body | test(\"!ci-\"; \"i\")) | {pr:$pr,user:.user.login,created_at,url:.html_url,body:.body}"
done
```

## Attach the Buildkite build URL as a follow-up comment

The `ci-build-me` webhook posts its own `^ https://buildkite.com/...` reply, but it can lag several minutes. A `^ <build-url>` follow-up comment pins the link into the PR for reviewers — worth doing, but **not worth stalling the turn for**: do not run a sleep/retry loop waiting for the build to appear. The person who asked for the trigger usually has the Buildkite UI open and sees it first. Post the trigger, report the comment URL, and either ask for the build URL or make **one** non-blocking query.

Pipeline slugs, all under the `o-1-labs-2` Buildkite org:

| Command | Pipeline slug |
|---|---|
| `!ci-build-me` | `mina-o-1-labs` |
| `!ci-nightly-me` | `mina-end-to-end-nightlies` |
| `!ci-debian-me` | `mina-build-debian` |
| `!ci-docker-me` | `mina-build-docker` |
| `!ci-toolchain-me` | `mina-toolchains-build` |
| `!ci-nix-me` | `mina-nix-experimental` |
| `!ci-docker-base-me` | `mina-docker-base-build` |
| `!ci-single-me` | `mina-single-job` |
| `!ci-artifacts-me` | `mina-artifacts` |

Query by **head commit SHA**, not branch: right after a trigger the newest branch build is often a *previous* commit, and on busy pipelines the branch's builds sit pages deep (`BUILDKITE_API_TOKEN` must be set; it is read-only, so it can look but not retry or cancel).

```bash
pipeline=mina-o-1-labs   # from the mapping above
sha=$(gh pr view "$pr" --repo MinaProtocol/mina --json headRefOid --jq .headRefOid)
curl -s -H "Authorization: Bearer $BUILDKITE_API_TOKEN" \
  "https://api.buildkite.com/v2/organizations/o-1-labs-2/pipelines/$pipeline/builds?commit=$sha&per_page=1" \
  | python3 -c 'import sys,json; b=json.load(sys.stdin); print(b[0]["web_url"]) if b else print("not yet")'
```

An empty result means only that the webhook has not landed yet — say so and move on, rather than looping. If it is still empty minutes later when someone checks, the trigger was probably skipped: see "Troubleshooting: the trigger produced no build". Never post a guessed or stale URL. Once you have a real one:

```bash
gh api repos/MinaProtocol/mina/issues/$pr/comments \
  -f body="^ $build_url" \
  --jq '.html_url'
```

## Troubleshooting: the trigger produced no build

A posted `!ci-*` comment that spawns no Buildkite build is almost always **not** an authorship/permissions problem. Comments posted via `gh api` are authored by the authenticated `gh` user — a real GitHub user, indistinguishable to the webhook from a comment typed in the web UI. Verify and rule this out rather than assuming a "bot vs human" difference:

```bash
gh api user --jq .login                    # who your gh posts as
gh api repos/MinaProtocol/mina/issues/comments/<id> --jq '{author:.user.login,type:.user.type}'
```

The real causes, in order of likelihood:

1. **The comment body was not an exact match.** For an `==` command, any extra character — a trailing note, a second line, a stray space — means no handler matched and nothing was logged. Re-post the command alone. See "Comment must match exactly, or by prefix".
2. **Author not a public org member.** Every command requires the comment author be a *public* member of the `MinaProtocol` org — private membership does not count, because the handler reads the sender's public `organizations_url`. Check with `gh api orgs/MinaProtocol/public_members/<login> -i` (204 = yes).
3. **The deployed webhook is older than the repo.** `frontend/ci-build-me` is one Google Cloud Function serving every branch, deployed by hand (see `frontend/ci-build-me/README.md`). A command that exists in `src/index.js` on your branch does nothing until someone redeploys. Suspect this first for a recently added command; ask whoever owns the deploy rather than retrying.
4. **PR not cleanly mergeable.** Empirically, a trigger sent seconds after a `git push` — while GitHub reports `mergeStateStatus: UNKNOWN` — can vanish, and the identical command a minute later succeeds. Nothing in the current `src/index.js` gates on mergeability, so treat this as observed behaviour rather than a documented rule: poll until it settles, then re-post.
   ```bash
   gh pr view "$pr" --repo MinaProtocol/mina --json mergeable,mergeStateStatus \
     --jq '{mergeable,mergeStateStatus}'   # want mergeable=MERGEABLE, status not DIRTY/UNKNOWN
   ```
5. **Webhook lag.** Genuine builds can take a couple of minutes to appear; keep polling by commit SHA (above) before concluding it was skipped.

Who actually created a build (confirms the webhook fired vs a manual Buildkite trigger):

```bash
curl -s -H "Authorization: Bearer $BUILDKITE_API_TOKEN" \
  "https://api.buildkite.com/v2/organizations/o-1-labs-2/pipelines/$pipeline/builds/<n>" \
  | python3 -c 'import sys,json; b=json.load(sys.stdin); print(b.get("source"), (b.get("creator") or {}).get("name"), b["commit"][:9])'
# source=api + the o1-labs token owner's name == the ci-build-me webhook fired
```

## Is the build actually failed?

A build's top-level `state: failed` does not always mean the deliverable failed — an ancillary job (cache-parity verification, flaky arm64-under-QEMU, an agent hitting `no space left on device`) can fail while every job that matters passed. Before reporting failure, inspect per-job state and confirm the real artifact:

```bash
curl -s -H "Authorization: Bearer $BUILDKITE_API_TOKEN" \
  "https://api.buildkite.com/v2/organizations/o-1-labs-2/pipelines/$pipeline/builds/<n>" \
  | python3 -c '
import sys,json
b=json.load(sys.stdin); print("build:", b["state"])
for j in b.get("jobs",[]):
    if j.get("type")=="script":
        print(" ", j.get("state"), "exit=%s"%j.get("exit_status"), j.get("name"))'
```

For a toolchain build specifically, the deliverable is the pushed image — verify it exists on docker.io regardless of the build's overall state (HTTP 200 = published):

```bash
tok=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:minaprotocol/mina-toolchain:pull" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $tok" \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
  "https://registry-1.docker.io/v2/minaprotocol/mina-toolchain/manifests/<7charsha>-bullseye-devnet"
```

If the images are published and only an unrelated verification job failed, say so explicitly instead of reporting a blanket failure.

## Response format after triggering

Keep it concise:

```text
Posted:
<comment URL>

Body:
!ci-single-me HardForkTestMixed
```

If no comment was posted because details were ambiguous, say what is missing and suggest the exact candidate command.
