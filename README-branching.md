# Mina Branching Policy

Mina's current public release is "berkeley", version 2.X. The next hardfork
release is "mesa" 3.X, staged on the `release/mesa` branch.

The development branches in progress in `mina` are as follows:

- `master`: current stable release, currently berkeley 2.X.
  - Never commit to it directly, except to introduce a hotfix.
- `compatible`: scheduled to be soft-fork released.
  - The staging branch for mainnet soft-fork releases.
  - It contains all the changes which are literally backwards compatible with
    the current mainnet deployment. Any nodes running a version of mina based
    off of `compatible` should connect to the current mainnet.
  - It serves as the preparation ground for the next mainnet soft-fork release.
- `release/mesa`: next hard-fork release branch / release candidate.
  - Contains all the new features that are scheduled for the mesa hard fork.
  - It is the active hard-fork branch maintained until the mesa hard fork
    upgrade, after which `compatible` will absorb its changes.
  - Replaces the legacy `berkeley`/`izmir` branches that were retired after the
    berkeley hard fork.
- `develop`: post-mesa changes not scoped for the mesa hard-fork upgrade.
  - In other words, `develop` is the next non-harmful release (after mesa).
  - Contains changes which break backwards compatibility, or changes that
    depend on past compatibility-breaking changes. "Not backwards compatible"
    means that a daemon running this version of mina will not connect to
    mainnet.
  - Major changes to the daemon, protocol, or crypto will sometimes cause
    backwards-compatibility breaking changes, and of course such changes need
    to be done with deliberation and are not to be taken lightly. Changes to
    infrastructure, auxiliary develop scripts, tests, CI, are usually not
    backwards-compatibility breaking, and thereby should go into `compatible`
    (unless you are doing something very special and you know what you're
    doing).
  - The difference between `develop` and `release/mesa` is that `release/mesa`
    will be the actual hardfork release, while `develop` is the subsequent
    softfork release candidate, softfork after mesa. `develop` is just not
    tested as rigorously, but it's softfork compatible with `release/mesa`.
- `o1js-main`: compatible with mainnet, but has latest `proof-systems`
  features so that they can be used in `o1js`.
  - Uses `o1js/main` and `o1js-bindings/main` as explained
    [here](https://github.com/o1-labs/o1js/blob/main/README-dev.md#branch-compatibility?).
  - When `proof-systems/develop` is too cutting-edge and the adaptations of
    its changes haven't been landed in mina, `o1js` will use the
    `proof-systems/o1js-main` branch which is lagging behind
    `proof-systems/develop` a bit.

The relationship between the branches is as presented:
`master ⊆ compatible ⊆ release/mesa ⊆ develop`.

- This means `compatible` includes all the changes in `master`, `release/mesa`
  all the changes in `compatible`, and so on. So `develop` contains all the
  changes from _all_ the stable branches, but also contains features that do
  not exist in any of the "subsets".
- The back-merging direction is thus left-to-right: whenever a feature lands
  in this chain, it has to be periodically "back-merged" to the right.
- The branches are merged in the other direction (upstream) only when
  released.
- When merely a new feature is introduced, it should aim at the exact target
  branch. This place depends on the feature, e.g. `compatible` for soft-fork
  features, `release/mesa` for the upcoming hard fork, `develop` for
  post-mesa / experimental work.

![Illustration of the branching strategy](https://github.com/MinaProtocol/mina-resources/blob/main/docs/res/branching_flow_david_wong.png)

### Hard forks / releases

Whenever a hard fork happens, the code in the corresponding release branch
(e.g. `release/mesa`) is released to become the new `master`.

- The intention is then to again have `compatible` as the next soft-fork
  branch.
  - The transition will be gradual: right after HF, `release/mesa` will be
    copied into both `master` _and_ `compatible`, and `develop` will remain as
    is for a while. PRs from `develop` will be gradually picked based on
    release scope and included in `compatible` for subsequent soft-fork
    releases.
  - The pre-mesa `compatible` is entirely discarded. The pre-mesa branch
    `release/mesa` is completely removed from both `mina` and `proof-systems`.
- `release/<version>` branches (e.g. `release/3.4.0`) are made off of
  `compatible` and tagged with alpha and beta tags until the code is deemed
  stable, then the `release/<version>` branch is merged into `master` and
  given a stable tag. Whenever code is tagged, if anything is missing in the
  downstream branches (`compatible`, `develop`) then the tagged branch is also
  merged back for consistency.

## Day to day: which branch should I use?

When developing a feature, use the general description of the branches above
to decide. Here's a quick rule:

- If a feature/enhancement/bug fix is not feature breaking, and scoped for
  mainnet, then base it off of `compatible`. If you're not sure whether or not
  your changes are breaking, they probably are not and should build upon
  `compatible`.
- If the feature is scoped for the next hard fork and is not compatible with
  running public mainnet, then base it off of the hard-fork branch
  (currently `release/mesa`).
- If a change is post-hard-fork (depends on mesa shipping, or is otherwise
  cutting-edge / not yet release-scoped), base it off of `develop`.

### Handling back-merging conflicts

We have CI jobs named `check-merges-cleanly-into-BRANCH` that fail if a PR
introduces changes conflicting with changes in a downstream branch `BRANCH`.
E.g. `check-merges-cleanly-into-develop` will check that a PR aimed at
`compatible` is easily back-mergable downstream up to `develop`. PR authors
must create new PRs against those branches to resolve conflicts before merging
the original PR.

If that CI job passes, then you can proceed and no further action is needed.

PRs resolving merge conflicts (merge-PRs) should only be merged after the
original PR is approved, and all changes from the original PR are incorporated
into the merge-PRs. Consider a PR which is made from `mybranch` against
`compatible`, and causes conflicts in `release/mesa` and `develop`. In this
case the workflow is as follows:

- Review and approve the original PR against `compatible` (PR-compatible). CI
  passes except for `check-merges-cleanly-into-*` jobs.
- Incorporate all changes from PR-compatible into a new PR against
  `release/mesa` (PR-mesa) and resolve conflicts. Concretely, make a new
  branch+PR based off of `mybranch` called `mybranch-mesa` (for example), and
  then merge `release/mesa` into `mybranch-mesa`. Fix any merge errors that
  result.
  - Keeping branches in sync: If after making e.g. `mybranch-mesa`, you need
    to make changes to `mybranch`, then do so, but make sure to merge the
    newly updated `mybranch` into `mybranch-mesa`. In order for the git magic
    to work, `mybranch-mesa` needs to be a superset of the commits from
    `mybranch`, and it also needs to be merged first.
- Similarly, incorporate all changes from PR-compatible into a new PR against
  `develop` (PR-develop) and resolve conflicts.
- Review, approve, and merge PR-mesa and PR-develop. They can be done in
  parallel.
- Rerun failing `check-merges-cleanly-into-*` jobs against the original
  PR-compatible and merge PR-compatible after CI is green.

The protocol team at o1labs will conduct weekly synchronization of all
branches for all non-conflicting changes to ensure a smooth experience for
everyone involved in the Mina repository. The protocol team will reach out to
respective teams if there are any conflicting changes (due to force-merges
performed mistakenly) and/or failing tests caused by code changes in the
upstream branches.
