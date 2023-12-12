# Mina Branching Policy

- `master`: current stable release.
  - It is frozen from the crypto side, does not depend on `proof-systems`.
  - Never commit to it directly, except to introduce a hotfix.
- `compatible`: scheduled to be released.
  - It contains all the changes which are literally backwards compatible with what people currently run on the mainnet. Any nodes running a version of mina based off of compatible should connect to the current mainnet.
- `rampup`: what is deployed on the testnet
  - Compatible with `mina#compatible`.
  - Never make PRs to `rampup` unless you're explicitly fixing a testnet bug.
- `berkeley`/`izmir`: next hardfork branch / release candidate.
  - Contains all the new features that are scheduled for the release (berkeley or izmir).
  - On releases. Current release is "mainnet", public. Next release is "berkeley", and the one after is "izmir". The "devnet" testnet is running from `master`, sometimes `compatible`, and features only the current release (not cutting edge/berkeley).
- `develop`: next non-harmful release, but without cutting edge new protocol features enabled (that might go into the next release).
  - Contains changes which break backwards compatibility, or changes that depend on past compatibility-breaking changes.  “Not backwards compatible” means that a daemon running this version of mina will not connect to mainnet.
  - Major changes to the daemon, protocol, or crypto will sometimes cause backwards-compatibility breaking changes, and of course such changes need to be done with deliberation and are not to be taken lightly.  Changes to infrastructure, auxiliary develop scripts, tests, CI, are usually not be backwards compatibility breaking, and thereby should go into compatible (unless you are doing something very special and you know what you’re doing).
  - How is `develop` different from `berkeley` currently? `berkeley` is like 2.0 will be the actual hardfork release, and `develop` is like 2.01 subsequent softfork release candidate, softfork after `berkeley`. `develop` is just not tested as rigorously, but it's softfork compatible with `berkeley`.
- Direction of merge:
  - The back-merging direction is as follows. `master` merges back to `compatible`, `compatible` merges back to `rampup` (currently running in berkeley incentivized testnet) (ignored). `rampup` merges back into next hardfork (now, `berkeley`), which then merges back into `develop`.
    - So `develop` contains all the changes from the more stable branches.
  - Merging forward (when introducing features/fixes) is up this stack, but the place the change is introduced can be different (e.g. `compatible` for soft features, `develop` for more experimental/next release).
- Hard fork/Release:
  - Whenever a hard fork happens, the code in  `develop` is released.  When this happens, the current `compatible` is entirely discarded and a new `compatible` gets created based off of `develop`
  - So after Berkeley release: `berkeley` branch will become the new `master`. `berkeley` will be removed from `proof-systems`. `develop` will be renamed into `compatible`.
- `o1js-main`: compatible with testnet, but has latest `proof-systems` features so that they can be used in `o1js`
  - mina changes from `rampup`
  - but `proof-systems#develop`


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
    - **TODO** ??? Apparently not used in `mina`, and does not have commits after February 2023. Abandoned?
    - After berkeley `compatible` will become properly synced with `mina` compatible.
    - Mina's `compatible`, similarly to mina's `master`, does not have `proof-systems`.
- `develop`: matches mina's `develop`, soft fork-compatibility.
  - small nuance: `proof-systems#develop` is used as a main branch for o1js.
      - **TODO** clarify, this seems to not match with https://github.com/o1-labs/o1js/blob/main/README-dev.md#branch-compatibility?
- `berkley`: future release, will be going out to berkeley. This is where hotfixes go.
- `master`: future feature work development, containing breaking changes. Anything that does not need to be released alongside mina.
    - Note that `mina`'s `master` does not depend on `proof-systems` at all, therefore current ``.
- `izmir`: next release after berkeley.
- In the future: `master`/`develop` will reverse roles and become something like gitflow.
- Currently `develop` should be back-merged into `master`.


