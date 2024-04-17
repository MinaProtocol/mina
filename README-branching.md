# Mina Branching Policy

Mina's current public release is "mainnet", version 1.X. The next hardfork release is "berkeley" 2.0, and the one planned after is "izmir" 3.0.

The development branches in progress in `mina` are as follows:
- `master`: current stable release, currently mainnet 1.X.
  - It is frozen from the crypto side, does not depend on `proof-systems`.
  - Never commit to it directly, except to introduce a hotfix.
- `compatible`: scheduled to be softwork released.
  - The staging branch for mainnet soft fork releases.
  - It contains all the changes which are literally backwards compatible with the current mainnet deployment. Any nodes running a version of mina based off of compatible should connect to the current mainnet.
  - It serves as the preparation ground for the next mainnet soft fork release.
- `rampup`: what is deployed on the testnet
  - The public incentivized network where an early version of the 2.0 hardfork is deployed for community testing.
  - `rampup` is a temporary branch maintained until public testnets requiring compatibility are running.
  - Never make PRs to `rampup` unless you're explicitly fixing a testnet bug.
- `berkeley`/`izmir`: next hardfork branch / release candidate.
  - Contains all the new features that are scheduled for the release (berkeley or izmir).
  - `berkeley` is a 2.0 temporary branch maintained until the hard fork after which compatible will include all berkeley changes.
  - The "devnet" testnet is running from `master`, sometimes `compatible`, and features only the current release (not cutting edge/berkeley).
- `develop`: 2.0 compatible changes not scoped for the 2.0 hard fork upgrade.
  - In other words, `develop` is next non-harmful release (after `berkeley`).
  - Is not *the most cutting edge: might not contain protocol features that scheduled for the subsequent (3.0) release.
  - Contains changes which break backwards compatibility, or changes that depend on past compatibility-breaking changes.  “Not backwards compatible” means that a daemon running this version of mina will not connect to mainnet.
  - Major changes to the daemon, protocol, or crypto will sometimes cause backwards-compatibility breaking changes, and of course such changes need to be done with deliberation and are not to be taken lightly.  Changes to infrastructure, auxiliary develop scripts, tests, CI, are usually not be backwards compatibility breaking, and thereby should go into compatible (unless you are doing something very special and you know what you’re doing).
  - The difference between `develop` and `berkeley` is that `berkeley` will be the actual hardfork release, while `develop` is subsequent softfork release candidate, softfork after `berkeley`. `develop` is just not tested as rigorously, but it's softfork compatible with `berkeley`. So if `berkeley` can be thought of as 2.0, then `develop` is 2.01.
- `o1js-main`: compatible with testnet, but has latest `proof-systems` features so that they can be used in `o1js`
  - Contains mina changes from `rampup`
  - But `proof-systems/develop` which by default is used by `mina/develop`.
  - Uses `o1js/main` and `o1js-bindings/main` as explained [here](https://github.com/o1-labs/o1js/blob/main/README-dev.md#branch-compatibility?).
  - When `proof-systems/develop` is too cutting-edge and the adaptations of its changes haven't been landed in mina, `o1js` will use the `proof-systems/o1js-main` branch which is lagging behind `proof-systems/develop` a bit.


The relationship between the branches is as presented: `master ⊆ compatible ⊆ rampup ⊆ berkeley ⊆ develop`.
- This means `compatible` includes all the changes in `master`, `rampup` all the changes in `compatible` and so on. So `develop` contains all the changes from *all* the stable branches, but also contains features that do not exist in any of the "subsets".
- The back-merging direction is thus left-to-right: whenever a feature lands in this chain, it has to be periodically "back-merged" to the right.
- The branches are merged in the other direction (upstream) only when released.
- When merely a new feature is introduced, it should aim at the exact target branch. This place depends on the feature, e.g. `compatible` for softfork features, `develop` for more experimental/next release, etc. And then the merged feature is back-propagated downstream (to the right).


![Illustration of the branching strategy](docs/res/branching_flow_david_wong.png)



### Hard forks / releases:

Whenever a hard fork happens, the code in the corresponding release branch, e.g. `berkeley`, is released to become the new `master`.
- The intention is then to again have `compatible` as a next soft-fork branch.
  - The transition will be gradual: right after HF, `berkeley` will be copied into both `master` *and* `compatible`, and `develop` will remain as is for a while. PRs from `develop` will be gradually picked based on release scope and included in `compatible` for subsequent soft-fork releases.
  - The pre-Berkeley `compatible` is entirely discarded. The pre-Berkeley branch `berkeley` is completely removed from both `mina` and `proof-systems`.
- `release/1.X.X` branches are made off of `compatible` and tagged with alpha and beta tags until the code is deemed stable, then the `release/1.X.X` branch is merged into `master` and given a stable tag. Whenever code is tagged, if anything is missing in the downstream branches (compatible, develop) then the tagged branch is also merged back for consistency.

## Day to day: which branch should I use?

When developing a feature, use the general description of the branches above to decide. Here's a quick rule:
- If a feature/enhancement/bug fix is not feature breaking, and scoped for a mainnet then base it off of `compatible`. If you’re not sure whether or not your changes are breaking, they probably are not and should build upon `compatible`.
- If the feature is scoped for hardfork and is not compatible against a running public testnet, then base it off of the hardfork branch (for example, `berkeley`).
- If it is a bug fix required for a public testnet testing upcoming hardfork then base it off of `rampup`.

### Handling back-merging conflicts

We have CI jobs named `check-merges-cleanly-into-BRANCH` that fail if a PR introduces changes conflicting with changes in a downstream branch `BRANCH`. E.g. `check-merges-cleanly-into-develop` will check that a PR aimed at `compatible` is easily back-mergable downstream up to `develop`. PR authors must create new PRs against those branches to resolve conflicts before merging the original PR.

If that CI job passes, then you can proceed and no further action is needed.

PRs resolving merge conflicts (merge-PRs) should only be merged after the original PR is approved, and all changes from the original PR are incorporated into the merge-PRs. Consider a PR which is made from `mybranch` branch against `rampup`, and causes conflicts in `berkeley` and `develop`. In this case the workflow is as follows:
- Review and approve the original PR against `rampup` (PR-rampup). CI passes except for `check-merges-cleanly-into-*` jobs.
- Incorporate all changes from PR-rampup into a new PR against `berkeley` (PR-berkeley) and resolve conflicts. Concretely, make a new branch+PR based off of `mybranch` called `mybranch-berkeley` (for example), and then merge `berkeley` into `mybranch-berkeley`. Fix any merge errors that result.
  - Keeping branches in sync: If after making e.g. `mybranch-berkeley`, you need to make changes to `mybranch`, then do so, but make sure to merge the newly updated `mybranch` into `mybranch-berkeley`. In order for the git magic to work, `mybranch-berkeley` needs to be a superset of the commits from `mybranch`, and it also needs to be merged first.
- Similarly, incorporate all changes from PR-rampup into a new PR against `develop` (PR-develop) and resolve conflicts.
- Review, approve, and merge PR-berkeley and PR-develop. They can be done in parallel.
- Rerun failing `check-merges-cleanly-into-*` jobs against the original PR-rampup and merge PR-rampup after CI is green.


The protocol team at o1labs will conduct weekly synchronization of all branches for all non-conflicting changes to ensure a smooth experience for everyone involved in the Mina repository. The protocol team will reach out to respective teams if there are any conflicting changes (due to force-merges performed mistakenly) and/or failing tests caused by code changes in the upstream branches.
