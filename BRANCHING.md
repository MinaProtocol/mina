# Mina Branching Policy

- `master`: current stable release.
  - It is frozen from the crypto side, does not depend on `proof-systems`.
  - Never commit to it directly, except to introduce a hotfix.
- `compatible`: scheduled to be released.
  - It contains all the changes which are literally backwards compatible with what people currently run on the mainnet. Any nodes running a version of mina based off of compatible should connect to the current mainnet.
- `rampup`: what is deployed on the testnet
  - Compatible with `compatible`.
  - Never make PRs to `rampup` unless you're explicitly fixing a testnet bug.
- `berkeley`/`izmir`: next hardfork branch / release candidate.
  - Contains all the new features that are scheduled for the release (berkeley or izmir).
  - On releases. Current release is "mainnet", public. Next release is "berkeley", and the one after is "izmir". The "devnet" testnet is running from `master`, sometimes `compatible`, and features only the current release (not cutting edge/berkeley).
- `develop`: next non-harmful release (after `berkeley`).
  - Does *not* contain cutting edge new protocol features enabled (that might go into the next release).
  - Contains changes which break backwards compatibility, or changes that depend on past compatibility-breaking changes.  “Not backwards compatible” means that a daemon running this version of mina will not connect to mainnet.
  - Major changes to the daemon, protocol, or crypto will sometimes cause backwards-compatibility breaking changes, and of course such changes need to be done with deliberation and are not to be taken lightly.  Changes to infrastructure, auxiliary develop scripts, tests, CI, are usually not be backwards compatibility breaking, and thereby should go into compatible (unless you are doing something very special and you know what you’re doing).
  - The difference between `develop` and `berkeley` is that `berkeley` will be the actual hardfork release, while `develop` is subsequent softfork release candidate, softfork after `berkeley`. `develop` is just not tested as rigorously, but it's softfork compatible with `berkeley`. So if `berkeley` can be thought of as 2.0, then `develop` is 2.01.
- Direction of merge:
  - The back-merging direction is `master` to `compatible` to `rampup` to the next hardfork (now, `berkeley`) to `develop`.
    - So `develop` contains all the changes from the more stable branches.
  - Merging forward (when introducing features/fixes) is up this stack, but the place the change is introduced can be different (e.g. `compatible` for softfork features, `develop` for more experimental/next release).
- Hard fork/Release:
  - Whenever a hard fork happens, the code in  `develop` is released.  When this happens, the current `compatible` is entirely discarded and a new `compatible` gets created based off of `develop`
  - So after Berkeley release: `berkeley` branch will become the new `master`. `berkeley` will be removed from `proof-systems`. `develop` will be renamed into `compatible`.
- `o1js-main`: compatible with testnet, but has latest `proof-systems` features so that they can be used in `o1js`
  - Contains mina changes from `rampup`
  - But `proof-systems/develop` which by default is used by `mina/develop`.
  - Uses `o1js/main` and `o1js-bindings/main` as explained [here](https://github.com/o1-labs/o1js/blob/main/README-dev.md#branch-compatibility?).
  - When `proof-systems/develop` is too cutting-edge and the adaptations of its changes haven't been landed in mina, `o1js` will use the `proof-systems/o1js-main` branch which is lagging behind `proof-systems/develop` a bit.


### Diagram

**TODO** fix diagram

![git-flow_david-wong.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/09e92777-0232-401b-be44-9689d39ce22a/git-flow_david-wong.png)

## Day to day: which branch should I use?

When developing a feature, if it’s not something that breaks compatibility, then you should be developing a feature branch, called `foo_COMP` for example, based off of `compatible`.  If you’re not sure whether or not your changes are breaking, they probably are not and should build upon compatible.

### Directions for merging your branch `foo_COMP`

- There is a CI job called `merges cleanly to develop` which runs whenever you have a PR off of `compatible`.  If that CI job passes, then you can simply merge `foo_COMP` into `compatible` , and no further action is needed.
- If `merges cleanly to develop` does NOT pass, then when you’re done with your changes to `foo_COMP` and the PR is all approved, make a new branch+PR based off of `foo_COMP` called `foo_DEVELOP` (for example), and then merge `develop` into `foo_DEVELOP`.  Fix any merge errors that result, then once `foo_DEVELOP` is approved, you can merge it into `develop`.
- Once `foo_DEVELOP` is fully landed into `develop`, then go and manually re-run the `merges cleanly to develop` CI job in the original `foo_COMP` PR.  The CI job should now pass and go green.  You can now merge `foo_COMP`
- If after making `foo_DEVELOP`, you need to make changes to `foo_COMP`, then make sure to merge the newly updated `foo_COMP` into `foo_DEVELOP`.  In order for the git magic to work, `foo_DEVELOP` needs to be a superset of the commits from `foo`, and it also needs to merge first.  You can make further changes post-merge in `foo_DEVELOP` as needed to ensure correctness

### Releases

(**TODO** is this outdated/needs to be removed?)

`release/1.X.X` branches are made off of `compatible` and tagged with alpha and beta tags until the code is deemed stable, then the `release/1.X.X` branch is merged into `master` and given a stable tag. Whenever code is tagged, if anything is missing in in the upstream branches (compatible, develop) then the tagged branch is also merged back for consistency.

`release/2.0.0`is the branch where Berkeley QA Net releases are being cut, between `compatible`and `develop` in the tree. So far nothing has been tagged there but there will be `2.0.0alphaX` tags once the code is more stable and we are closer to the Incentivized testnet.

Unless it is an emergency, code should flow from feature branches into `compatible` then in batches into the release branch for tagging and testing

# proof-systems Branching policy
Generally, proof-systems intends to be synchronized with the mina repository, and so its branching policy is quite similar. However several important distinctions exist that are a result of proof-systems having been created after the mainnet release (**TODO** ?).

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
