Adapted from https://github.com/eddies/github-webhook-cloud-function

For JS code, only `src/index.js` was modified.

# CI Build Me

This proxy listens on a webhook via a Google Cloud Function and conditionally starts the Mina buildkite pipeline.

We currently dispatch a build the moment the `ci-build-me` label is added and any time commits are pushed to a pull-request that has this label attached to it.

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
