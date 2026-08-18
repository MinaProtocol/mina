Adapted from https://github.com/eddies/github-webhook-cloud-function

For JS code, only `src/index.js` was modified.

# CI Build Me

This proxy listens on a webhook via a Google Cloud Function and conditionally starts the Mina buildkite pipeline.

We currently dispatch a build the moment the `ci-build-me` label is added and any time commits are pushed to a pull-request that has this label attached to it.

## Commands

A comment on a pull request starts a build of **that pull request's own
branch**. The function is one deployment for the whole repository, so a change
here is a change for `compatible`, for `master`, for the release branches and
for `develop` at once.

### Artifacts

```
!ci-artifacts-me docker set=automode profile=devnet codename=bullseye
!ci-artifacts-me debian set=prefork codename=bullseye
!ci-artifacts-me apps   codename=bullseye instrumented=true
```

Builds what it is told and triages nothing. The first word is the layer
(`docker`, `debian`, `apps`); the rest are `key=value`. Naming no `set=` builds
the whole layer. See `src/artifacts.js` for the keys and
`buildkite/src/Constants/Artifact/Sets.dhall` for the sets.

Pipeline: **`mina-artifacts`**, which uploads
`buildkite/src/Entrypoints/RunSelection.dhall`.

### The older commands

`!ci-build-me`, `!ci-nightly-me`, `!ci-docker-me`, `!ci-debian-me`,
`!ci-docker-base-me`, `!ci-toolchain-me`, `!ci-single-me`. These triage a diff
and are unchanged.

## Adding a command that needs a new pipeline

**The entrypoint a pipeline uploads is not on every branch, and a pipeline runs
one command whatever the branch it builds.**

`!ci-artifacts-me` needs `buildkite/src/Entrypoints/RunSelection.dhall`, which
exists on `develop` and on no other branch. Repointing `mina-build-docker` at it
would have broken every `!ci-docker-me` on `compatible` and on `master`, because
that pipeline would then upload a file those branches do not have.

So a command whose entrypoint is not yet everywhere gets:

1. a **new comment handler**, leaving the old ones exactly as they were, and
2. a **new pipeline**, leaving the old pipelines' commands exactly as they were.

A branch without the entrypoint then fails only when someone uses the new
command on it, and every old command keeps working everywhere.
`test/artifacts.test.js` reads `src/index.js` and fails if an old command stops
pointing at the pipeline it always pointed at.

Once every live branch carries the entrypoint, the old names can be pointed at
the new handler and the old pipelines retired.

## Test

1. `yarn start`
2. `ngrok http 8080`
3. In GitHub's settings, add a webhook listening to the `pull_request` event for your ngrok URL
4. Label PRs and push to them as you wish.

## Deploy

Acquire `$GITHUB_SECRET` and `$BUILDKITE_API_ACCESS_TOKEN` from our AWS secret store on us-west-2.

```
gcloud functions deploy githubWebhookHandler \
  --trigger-http --runtime nodejs10 --memory 128MB \
  --set-env-vars GITHUB_SECRET=$GITHUB_SECRET,BUILDKITE_API_ACCESS_TOKEN=$BUILDKITE_API_ACCESS_TOKEN \
  --project o1labs-192920
```

This deploys to https://us-central1-o1labs-192920.cloudfunctions.net/githubWebhookHandler

## Update Branch Protection Rules

In order to gate a new branch with this mechanism, github needs to see this job run (but generally we don't actually run a job here,
 just block on its existence). This means that if months pass between changes, github will stop showing the buildkite/mina-pr-gating job
 in their UI and therefore you cannot block new branches on it.

To fix this, run the PR gating job manually in the builkite UI here: https://buildkite.com/o-1-labs-2/mina-pr-gating

Just running the job once will re-populate it in github's dropdown menus so that you can add the gate to a new branch.
This does not require a redeploy unless you're also intending to change the mechanism of activation or the list of users with this power.
