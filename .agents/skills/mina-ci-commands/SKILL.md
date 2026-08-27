---
name: mina-ci-commands
description: Use when the user asks to trigger Mina CI, Buildkite CI, PR CI, !ci-build-me, !ci-single-me, !ci-docker-me, !ci-nightly-me, or other MinaProtocol/mina GitHub comment CI commands. Use this skill to choose the right magic comment and post it with gh CLI on Mina PRs instead of guessing command syntax.
---

# Mina CI Commands

Use this skill when working in or against `MinaProtocol/mina` and the user asks to trigger CI, rerun Buildkite, run a specific job, build docker/debian/toolchain artifacts, run nightly CI, or post a `!ci-*` PR comment.

The Mina repo uses GitHub PR comments as CI control commands. Prefer `gh` CLI; do not invent syntax. If the target PR or job/filter is ambiguous, ask one focused question before commenting.

## Safety checks before posting

1. Identify the PR number or URL.
2. Confirm the repository is `MinaProtocol/mina` unless the user explicitly gives another repo.
3. If the requested command is broad or expensive (`!ci-build-me`, `!ci-nightly-me`, broad `!ci-docker-me`), proceed if the user clearly requested it; otherwise ask confirmation.
4. Prefer exact command-only comments unless extra context is useful. The CI bot mostly keys off the command text.
5. For PR-build commands (`!ci-build-me`, `!ci-nightly-me`, `!ci-docker-me`), confirm the PR is cleanly mergeable first — the webhook silently skips a non-mergeable PR, including the brief `UNKNOWN` window right after a push. Details and the poll command are in "Troubleshooting: the trigger produced no build".
6. After posting, return the GitHub comment URL and the exact command body, then attach the triggered build as a follow-up `^ <build-url>` comment (see "Attach the Buildkite build URL as a follow-up comment").

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

## Commands handled by `frontend/ci-build-me`

These commands are handled by the Mina `frontend/ci-build-me` webhook on `issue_comment.created` for PRs. The comment author must be a public member of the `MinaProtocol` GitHub org for most commands.

| Command | Buildkite pipeline | Use when |
|---|---|---|
| `!ci-build-me` | `mina-o-1-labs` | Normal broad PR CI / rerun standard CI. |
| `!ci-nightly-me` | `mina-end-to-end-nightlies` | Nightly/end-to-end checks. Heavier than normal CI. |
| `!ci-nix-me` | `mina-nix-experimental` | Nix experimental pipeline. |
| `!ci-debian-me` | `mina-build-debian` | Debian package build pipeline. |
| `!ci-docker-me` | `mina-build-docker` | Docker image build pipeline; may be filtered. |
| `!ci-toolchain-me` | `mina-toolchains-build` | Rebuild the opam toolchain images (tag `Toolchain`). Takes hours. Does **not** touch the `mina-base` images. |
| `!ci-docker-base-me` | `mina-docker-base-build` | Rebuild the shared `mina-base` images (tag `Base`) for all codenames. Use after changing `dockerfiles/stages/1-base-deps`, or to publish/refresh the `minaBase*` pins. |
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

Takes no arguments. It triggers `mina-docker-base-build` with:

```text
BUILDKITE_PIPELINE_FILTER=BaseDockersOnly
BUILDKITE_PIPELINE_JOB_SELECTION=Full
```

`BaseDockersOnly` maps to the `Base` tag, which only the `MinaBaseArtifact*` jobs carry, so the opam toolchain images are excluded. `Full` skips dirty-when triage, so the rebuild runs even when the PR touched nothing under `dockerfiles/stages/`.

This is the **only** way these jobs run: they carry neither `Fast` nor `Long`, so the standard PR/nightly pipeline stages (`FastOnly`, `LongAndVeryLong`, `TearDownOnly`) filter them out regardless of `dirtyWhen`.

Each selected job pushes to `docker.io/minaprotocol/mina-base:<githash>-<codename>-<network>` and writes `${CACHE_ROOT}/mina-base/<tag>.tar.zst` to the storagebox. After it finishes, bump the `minaBase*` pins in `buildkite/src/Constants/ContainerImages.dhall` to the new githash, otherwise the daemon/archive builds keep falling back to building the base-deps stage inline.

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

If any of `arch`, `profile`, or `codename` is missing, the current handler falls back to the broad filter:

```text
BUILDKITE_PIPELINE_FILTER=DockerBuild
```

Do not use old examples like `network=testnet-generic`; the current handler ignores that key.

## `!ci-single-me <JobName>`

`!ci-single-me` is not handled by `frontend/ci-build-me`. It is a separate mechanism that runs `buildkite/scripts/run-single-job-with-deps.sh` or equivalent logic.

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

The `ci-build-me` webhook eventually posts its own `^ https://buildkite.com/...` reply, but it can lag several minutes. After triggering a `!ci-*` command, locate the build it started and post a follow-up comment pinning the URL into the PR's comment section, mirroring the bot's own `^ <url>` format. This gives reviewers a direct link without waiting on the bot.

Each command maps to a pipeline slug (see the tables above), all under the `o-1-labs-2` Buildkite org:

| Command | Pipeline slug |
|---|---|
| `!ci-build-me` | `mina-o-1-labs` |
| `!ci-nightly-me` | `mina-end-to-end-nightlies` |
| `!ci-debian-me` | `mina-build-debian` |
| `!ci-docker-me` | `mina-build-docker` |
| `!ci-toolchain-me` | `mina-toolchains-build` |
| `!ci-nix-me` | `mina-nix-experimental` |

Match on the **head commit SHA**, not just the branch (`BUILDKITE_API_TOKEN` must be set). A branch filter alone is unreliable: right after a trigger the newest branch build is often a *previous* commit (webhook lag), and on busy pipelines the branch's builds may sit several pages deep. Query by commit and poll until the build for the current head appears:

```bash
pipeline=mina-o-1-labs   # from the mapping above
sha=$(gh pr view "$pr" --repo MinaProtocol/mina --json headRefOid --jq .headRefOid)
for i in $(seq 1 20); do
  build_url=$(curl -s -H "Authorization: Bearer $BUILDKITE_API_TOKEN" \
    "https://api.buildkite.com/v2/organizations/o-1-labs-2/pipelines/$pipeline/builds?commit=$sha&per_page=1" \
    | python3 -c 'import sys,json; b=json.load(sys.stdin); print(b[0]["web_url"]) if b else print("")')
  [ -n "$build_url" ] && break
  sleep 30   # webhook lag; keep polling
done
```

If polling never finds a build (empty after several minutes), the trigger was almost certainly skipped — jump to "Troubleshooting: the trigger produced no build" rather than posting a stale/guessed URL. Once found, post it exactly mirroring the bot's format (leading `^ `):

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

1. **PR not cleanly mergeable.** The `ci-build-me` path skips a PR whose `mergeStateStatus` is `DIRTY`/`CONFLICTING` — or `UNKNOWN`, the transient state GitHub reports for a few seconds after every push while it recomputes. A trigger fired in that window is silently dropped. This is the most common surprise: a trigger sent seconds after a `git push` fails, the identical command a minute later succeeds. Poll until it settles, then re-post:
   ```bash
   gh pr view "$pr" --repo MinaProtocol/mina --json mergeable,mergeStateStatus \
     --jq '{mergeable,mergeStateStatus}'   # want mergeable=MERGEABLE, status not DIRTY/UNKNOWN
   ```
2. **Author not a public org member.** Most commands require the comment author be a *public* member of the `MinaProtocol` org. Check with `gh api orgs/MinaProtocol/public_members/<login> -i` (204 = yes).
3. **Webhook lag.** Genuine builds can take a couple of minutes to appear; keep polling by commit SHA (above) before concluding it was skipped.

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
