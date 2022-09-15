# Branch management: `compatible` vs `develop`

The first section describes the reasoning behind the current state of branching,
and the second section gives you a few tips on how to handle this on a day to
day basis.

## Rationale

Instead of a single `main` or `master` branch, there are two active branches
`compatible` and `develop` at all times, where you might want to make changes.

- `compatible` contains all changes which are literally backwards compatible
  with what people currently run on mainnet.  Any nodes running a version of
  mina based off of compatible should connect to current mainnet just fine.
- `develop` contains changes which break backwards compatibility, or changes
  that depend on past compatibility-breaking changes.  “Not backwards
  compatible” means that a daemon running this version of mina will not connect
  to mainnet.

Major changes to the daemon, protocol, or crypto sometimes will sometimes cause
backwards-compatibility breaking changes, and of course such changes need to be
done with deliberation and are not to be taken lightly.  Changes to
infrastructure, auxiliary develop scripts, tests, CI, are usually not be
backwards compatibility breaking, and thereby should go into compatible (unless
you are doing something very special and you know what you’re doing).

On a semi-regular basis, `compatible` gets manually merged into `develop` so
that — generally speaking — `develop` contains all changes in `compatible.` As
such, `develop` is a superset of `compatible` i.e. `develop` contains everything
that `compatible` contains, and more.

### Hard fork

Whenever a hard fork happens, the code in  `develop` is released. When this
happens, the current `compatible` is entirely discarded and a new `compatible`
gets created based off of `develop`

![Illustration of the branching strategy](docs/res/branching_flow.png)

### Releases

`release/1.X.X` branches are made off of `compatible` and tagged with alpha and
beta tags until the code is deemed stable, then the `release/1.X.X` branch is
merged into `master` and given a stable tag. Whenever code is tagged, if
anything is missing in in the upstream branches (compatible, develop) then the
tagged branch is also merged back for consistency.

`release/2.0.0`is the branch where Berkeley QA Net releases are being cut,
between `compatible`and `develop` in the tree. So far nothing has been tagged
there but there will be `2.0.0alphaX` tags once the code is more stable and we
are closer to the Incentivized testnet.

Unless it is an emergency, code should flow from feature branches
into `compatible`then in batches into the release branch for tagging and testing

## Day to day

When developing a feature, if it’s not something that breaks compatibility, then
you should be developing a feature branch, called `foo` for example, based off
of `compatible`.  If you’re not sure whether or not your changes are breaking,
they probably are not and should build upon compatible.

There is a CI job called “merges cleanly to develop” which runs whenever you
have a PR off of `compatible`.  If that CI job passes, then you can simply merge
`foo` into `compatible`.  If it does not pass, then when you’re done with your
changes to `foo` and the PR is all approved, then make a new branch+PR based off
of your original PR  called `foo_DEVELOP` (for example), and then merge
`develop` into `foo_DEVELOP`.  Fix any merge errors that result, then once
`foo_DEVELOP` is approved, you can merge it into `develop`.  Once that’s done,
the “merges cleanly to develop” CI job in your original `foo` PR should
automagically start passing when you manually re-run it in CI, in which case you
can merge.

If, after making `foo_DEVELOP`, you need to make changes to `foo`, then make
sure to merge `foo` into `foo_DEVELOP`.  In order for the git magic to work,
`foo_DEVELOP` needs to be a superset of the commits from `foo`, and it also
needs to merge first.  You can make further changes post-merge in `foo_DEVELOP`
as needed to ensure correctness.
