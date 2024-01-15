# Mina Branching Policy


The development branches in progress in `mina` are as follows:
- `master`: current stable release.
  - It is frozen from the crypto side, does not depend on `proof-systems`.
  - Never commit to it directly, except to introduce a hotfix.
- `compatible`: scheduled to be released.
  - The staging branch for mainnet soft fork releases.
  - It contains all the changes which are literally backwards compatible with the current mainnet deployment. Any nodes running a version of mina based off of compatible should connect to the current mainnet.
  - It serves as the preparation ground for the next mainnet soft fork release.
- `rampup`: what is deployed on the testnet
  - Compatible with `compatible`.
  - The public incentivized network where an early version of the 2.0 hardfork is deployed for community testing.
  - `rampup` is a temporary branch maintained until public testnets requiring compatibility are running.
  - Never make PRs to `rampup` unless you're explicitly fixing a testnet bug.
- `berkeley`/`izmir`: next hardfork branch / release candidate.
  - Contains all the new features that are scheduled for the release (berkeley or izmir).
  - `berkeley` is a 2.0 temporary branch maintained until the hard fork after which compatible will include all berkeley changes.
  - On releases. Current release is "mainnet" 1.0, public. Next release is "berkeley" 2.0, and the one after is "izmir" 3.0.
  - The "devnet" testnet is running from `master`, sometimes `compatible`, and features only the current release (not cutting edge/berkeley).
- `develop`: 2.0 compatible changes not scoped for the 2.0 hard fork upgrade.
  - In other words, `develop` is next non-harmful release (after `berkeley`).
  - Is not *the most cutting edge: might not contain protocol features that scheduled for the subsequent (3.0) release.
  - Contains changes which break backwards compatibility, or changes that depend on past compatibility-breaking changes.  “Not backwards compatible” means that a daemon running this version of mina will not connect to mainnet.
  - Major changes to the daemon, protocol, or crypto will sometimes cause backwards-compatibility breaking changes, and of course such changes need to be done with deliberation and are not to be taken lightly.  Changes to infrastructure, auxiliary develop scripts, tests, CI, are usually not be backwards compatibility breaking, and thereby should go into compatible (unless you are doing something very special and you know what you’re doing).
  - The difference between `develop` and `berkeley` is that `berkeley` will be the actual hardfork release, while `develop` is subsequent softfork release candidate, softfork after `berkeley`. `develop` is just not tested as rigorously, but it's softfork compatible with `berkeley`. So if `berkeley` can be thought of as 2.0, then `develop` is 2.01.


The relationship between the branches is `master ⊆ compatible ⊆ rampup ⊆ berkeley ⊆ develop`.
- This means `compatible` includes all the changes in `master`, `rampup` all the changes in `compatible` and so on. So `develop` contains all the changes from *all* the stable branches, but also contains features that do not exist in any of the "subsets".
- The back-merging direction is thus left-to-right: whenever a feature lands in this chain, it has to be periodically "back-merged" to the right.
- The branches are not merged in the other direction. When a new feature is introduced, it should aim at the exact target branch. This place depends on the feature (e.g. `compatible` for softfork features, `develop` for more experimental/next release). And then the feature is propagated to the right.


![Illustration of the branching strategy](docs/res/branching_flow_david_wong.png)


### On back-merging conflicts

We have CI jobs named `check-merges-cleanly-into-*` that fail if a PR introduces changes conflicting with downstream branch changes. PR authors must create new PRs against those branches to resolve conflicts before merging the original PR.

PRs resolving merge conflicts (merge-PRs) should only be merged after the original PR is approved, and all changes from the original PR are incorporated into the merge-PRs. For example: Consider a PR is made against `rampup` and causes conflicts in `berkeley` and `develop`. In this case the workflow is as follows:
- Review and approve the original PR against `rampup` (PR-rampup). CI passes except for `check-merges-cleanly-into-*` jobs.
- Incorporate all changes from PR-rampup into a new PR against `berkeley` (PR-berkeley) and resolve conflicts.
- Incorporate all changes from PR-rampup into a new PR against `develop` (PR-develop) and resolve conflicts.
- Review, approve, and merge PR-berkeley and PR-develop. They can be done in parallel.
- Rerun failing check-merges-cleanly-into-* jobs against PR-rampup and merge PR-rampup after CI is green.


The protocol team at o1labs will conduct weekly synchronization of all branches for all non-conflicting changes to ensure a smooth experience for everyone involved in the Mina repository. The protocol team will reach out to respective teams if there are any conflicting changes (due to force-merges performed mistakenly) and/or failing tests caused by code changes in the upstream branches


### Hard forks / releases:

Whenever a hard fork happens, the code in  `develop` is released.  When this happens, the current `compatible` is entirely discarded and a new `compatible` gets created based off of `develop`
- `release/1.X.X` branches are made off of `compatible` and tagged with alpha and beta tags until the code is deemed stable, then the `release/1.X.X` branch is merged into `master` and given a stable tag. Whenever code is tagged, if anything is missing in in the upstream branches (compatible, develop) then the tagged branch is also merged back for consistency.
- So after Berkeley release: `berkeley` branch will become the new `master`. `berkeley` will be removed from `proof-systems`. `develop` will be renamed into `compatible`.
`o1js-main`: compatible with testnet, but has latest `proof-systems` features so that they can be used in `o1js`
- Contains mina changes from `rampup`
- But `proof-systems/develop` which by default is used by `mina/develop`.
- Uses `o1js/main` and `o1js-bindings/main` as explained [here](https://github.com/o1-labs/o1js/blob/main/README-dev.md#branch-compatibility?).
- When `proof-systems/develop` is too cutting-edge and the adaptations of its changes haven't been landed in mina, `o1js` will use the `proof-systems/o1js-main` branch which is lagging behind `proof-systems/develop` a bit.


## Day to day: which branch should I use?

When developing a feature, if it’s not something that breaks compatibility, then you should be developing a feature branch, called `foo_COMP` for example, based off of `compatible`.  If you’re not sure whether or not your changes are breaking, they probably are not and should build upon compatible.

### Directions for merging your branch `foo_COMP`

- There is a CI job called `merges cleanly to develop` which runs whenever you have a PR off of `compatible`.  If that CI job passes, then you can simply merge `foo_COMP` into `compatible` , and no further action is needed.
- If `merges cleanly to develop` does NOT pass, then when you’re done with your changes to `foo_COMP` and the PR is all approved, make a new branch+PR based off of `foo_COMP` called `foo_DEVELOP` (for example), and then merge `develop` into `foo_DEVELOP`.  Fix any merge errors that result, then once `foo_DEVELOP` is approved, you can merge it into `develop`.
- Once `foo_DEVELOP` is fully landed into `develop`, then go and manually re-run the `merges cleanly to develop` CI job in the original `foo_COMP` PR.  The CI job should now pass and go green.  You can now merge `foo_COMP`
- If after making `foo_DEVELOP`, you need to make changes to `foo_COMP`, then make sure to merge the newly updated `foo_COMP` into `foo_DEVELOP`.  In order for the git magic to work, `foo_DEVELOP` needs to be a superset of the commits from `foo`, and it also needs to merge first.  You can make further changes post-merge in `foo_DEVELOP` as needed to ensure correctness



# proof-systems Branching policy

Generally, proof-systems intends to be synchronized with the mina repository, and so its branching policy is quite similar. However several important (some, temporary) distinctions exist:

- `compatible`:
    - Compatible with `rampup` in `mina`.
    - Mina's `compatible`, similarly to mina's `master`, does not have `proof-systems`.
- `berkley`: future hardfork release, will be going out to berkeley.
  - This is where hotfixes go.
- `develop`: matches mina's `develop`, soft fork-compatibility.
  - Also used by `mina/o1js-main` and `o1js/main`.
- `master`: future feature work development, containing breaking changes. Anything that does not need to be released alongside mina.
    - Note that `mina`'s `master` does not depend on `proof-systems` at all.
- `izmir`: next hardfork release after berkeley.
- In the future:
  - `master`/`develop` will reverse roles and become something like gitflow.
  - After Berkeley release `compatible` will become properly synced with `mina/compatible`.
- Direction of merge:
  - Back-merging: `compatible` into `berkeley` into `develop` into `master`.
  - Front-merging (introducing new features): other direction, but where you start depends on where the feature belongs.