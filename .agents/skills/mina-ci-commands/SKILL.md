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
5. After posting, return the GitHub comment URL and the exact command body.

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
| `!ci-toolchain-me` | `mina-toolchains-build` | Toolchain build pipeline. |
| `!approved-for-mainnet` | `mina-pr-gating` | Mainnet approval/gating command; restricted to specific approvers. |

Examples:

```bash
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-build-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-nightly-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-debian-me' --jq '.html_url'
gh api repos/MinaProtocol/mina/issues/$pr/comments -f body='!ci-toolchain-me' --jq '.html_url'
```

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

## Response format after triggering

Keep it concise:

```text
Posted:
<comment URL>

Body:
!ci-single-me HardForkTestMixed
```

If no comment was posted because details were ambiguous, say what is missing and suggest the exact candidate command.
