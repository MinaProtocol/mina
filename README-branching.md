# Mina Branching Policy

Mina's current public release is "berkeley", version 2.X. The next hardfork
release is "mesa" 3.X.

## Long-lived development branches

These are the branches contributors target. PRs are made against one of
these:

- `master`: current stable release, currently berkeley 2.X.
  - Never commit to it directly, except to introduce a hotfix.
- `compatible`: scheduled to be soft-fork released.
  - The staging branch for mainnet soft-fork releases.
  - It contains all the changes which are literally backwards compatible with
    the current mainnet deployment. Any nodes running a version of mina based
    off of `compatible` should connect to the current mainnet.
  - It serves as the preparation ground for the next mainnet soft-fork release.
- `develop`: changes that break mainnet compatibility, including features
  scoped for the next hard fork.
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
- `o1js-main`: compatible with mainnet, but has latest `proof-systems`
  features so that they can be used in `o1js`.
  - Uses `o1js/main` and `o1js-bindings/main` as explained
    [here](https://github.com/o1-labs/o1js/blob/main/README-dev.md#branch-compatibility?).
  - When `proof-systems/develop` is too cutting-edge and the adaptations of
    its changes haven't been landed in mina, `o1js` will use the
    `proof-systems/o1js-main` branch which is lagging behind
    `proof-systems/develop` a bit.

The relationship between the long-lived branches is:
`master ⊆ compatible ⊆ develop`.

- `compatible` includes all the changes in `master`, and `develop` includes
  all the changes in `compatible`. So `develop` contains all the changes from
  _all_ the stable branches, but also contains features that do not exist in
  the "subsets".
- The back-merging direction is thus left-to-right: whenever a feature lands
  in this chain, it has to be periodically "back-merged" to the right.
- The branches are merged in the other direction (upstream) only when
  released.
- When merely a new feature is introduced, it should aim at the exact target
  branch. This place depends on the feature, e.g. `compatible` for soft-fork
  features and `develop` for breaking / hard-fork-scoped / experimental work.

![Illustration of the branching strategy](https://github.com/MinaProtocol/mina-resources/blob/main/docs/res/branching_flow_david_wong.png)

## Short-lived release branches

`release/<name>` branches are **not** development targets — they are
short-lived branches cut from a long-lived branch when it is time to actually
ship a release. Examples:

- `release/<version>` (e.g. `release/3.4.0`) — soft-fork release candidates,
  cut from `compatible`. Tagged with alpha and beta tags until the code is
  deemed stable, then merged into `master` and given a stable tag.
- `release/<hardfork-name>` (e.g. `release/mesa`) — hard-fork release
  candidate, cut when a hard fork is ready to ship.

Whenever code is tagged, if anything is missing in the downstream long-lived
branches (`compatible`, `develop`) then the tagged branch is also merged back
for consistency.

Contributors should **not** open PRs against `release/*` branches as part of
normal feature work. If a feature is hard-fork-scoped, target `develop`; if
it's soft-fork-scoped, target `compatible`. The release manager will pick the
work into a release branch when ready.

### Hard forks

Whenever a hard fork happens, the code in the corresponding hard-fork release
branch (e.g. `release/mesa`) is released to become the new `master`.

- The intention is then to again have `compatible` as the next soft-fork
  branch.
  - The transition will be gradual: right after HF, the hard-fork release
    branch will be copied into both `master` _and_ `compatible`, and
    `develop` will remain as is for a while. PRs from `develop` will be
    gradually picked based on release scope and included in `compatible` for
    subsequent soft-fork releases.
  - The pre-HF `compatible` is entirely discarded. The hard-fork release
    branch is then removed from both `mina` and `proof-systems`.

## Day to day: which branch should I use?

When developing a feature, use the general description of the long-lived
branches above to decide. Here's a quick rule:

- If a feature/enhancement/bug fix is not feature breaking, and scoped for
  mainnet, then base it off of `compatible`. If you're not sure whether or
  not your changes are breaking, they probably are not and should build upon
  `compatible`.
- If the change is breaking — for example, scoped for the next hard fork, or
  otherwise incompatible with running public mainnet — base it off of
  `develop`.
- Do not target `release/*` branches; those are managed by the release
  process.

### Handling back-merging conflicts

We have CI jobs named `check-merges-cleanly-into-BRANCH` that fail if a PR
introduces changes conflicting with changes in a downstream branch `BRANCH`.
E.g. `check-merges-cleanly-into-develop` will check that a PR aimed at
`compatible` is easily back-mergable downstream up to `develop`. PR authors
must create new PRs against those branches to resolve conflicts before
merging the original PR.

If that CI job passes, then you can proceed and no further action is needed.

PRs resolving merge conflicts (merge-PRs) should only be merged after the
original PR is approved, and all changes from the original PR are
incorporated into the merge-PRs. Consider a PR which is made from `mybranch`
against `compatible` and causes conflicts in `develop`. In this case the
workflow is as follows:

- Review and approve the original PR against `compatible` (PR-compatible).
  CI passes except for `check-merges-cleanly-into-*` jobs.
- Incorporate all changes from PR-compatible into a new PR against `develop`
  (PR-develop) and resolve conflicts. Concretely, make a new branch+PR based
  off of `mybranch` called `mybranch-develop` (for example), and then merge
  `develop` into `mybranch-develop`. Fix any merge errors that result.
  - Keeping branches in sync: If after making `mybranch-develop`, you need
    to make changes to `mybranch`, then do so, but make sure to merge the
    newly updated `mybranch` into `mybranch-develop`. In order for the git
    magic to work, `mybranch-develop` needs to be a superset of the commits
    from `mybranch`, and it also needs to be merged first.
- Review, approve, and merge PR-develop.
- Rerun failing `check-merges-cleanly-into-*` jobs against the original
  PR-compatible and merge PR-compatible after CI is green.

The protocol team at o1labs will conduct weekly synchronization of all
branches for all non-conflicting changes to ensure a smooth experience for
everyone involved in the Mina repository. The protocol team will reach out
to respective teams if there are any conflicting changes (due to force-merges
performed mistakenly) and/or failing tests caused by code changes in the
upstream branches.
