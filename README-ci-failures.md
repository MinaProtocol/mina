CI jobs are dispatched by a script which responds to both the `ci-build-me`
label and comments by MinaProtocol organization members containing exactly
`!ci-build-me`. If your CI job has not started after adding the `ci-build-me`
label, please comment on the pull request with `!ci-build-me` to attempt to
re-trigger the script.

**Please note:**
* If you encounter an error where jobs are not run, it should normally suffice
  to retry the script with a `!ci-build-me` comment on your PR when the fix has
  been deployed.
* If your CI error is related to a timeout logged by one of the integration
  test runnners, this is a known issue and re-running the test in the CircleCI
  interface will usually succeed.

If CI jobs are not running after applying both the `ci-build-me` label and
comment, you may be able to find and fix the error in the script. The script
lives in `frontend/ci-build-me/src/index.js`, and instructions for deploying
the new version are in the readme at `frontend/ci-build-me/README.md`. You
should still follow normal procedure: submit a pull request and await approval
for the changes before attempting to deploy the fixed script.

If an issue arises, please post an update in both `development` on the Mina
Protocol discord and `engineering-internal` on the O(1) Labs discord with the
details and links to the failures.

Where you have a bugfix for failing CI, or are seeing a CI failure across
multiple PRs, the best people to contact are:
* @bkase (bkase#2492 on discord) (Europe - misc.)
* @lk86 (linuskrom#2287 on discord) (US West Coast)
* @OxO1 (awilson#6424 on discord) (US West Coast)
* @mrmr1993 (matthew#4797 on discord) (UK)
