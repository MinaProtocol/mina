## Summary
[summary]: #summary

Moving to a Git Flow based release process with a hardened release branch and regular release cadence.

## Motivation

[motivation]: #motivation

We need a regular release process, and it's best to pick a standard rather than reinventing the wheel because there is stable tooling available and resources online to get help.

## Detailed design

[detailed-design]: #detailed-design

### Real Release Branches

This time our "release/beta" branch wasn't really a release branch. In the future, these will be frozen and only critical user-impacting bug fixes will be allowed in. If you do want to make one of these fixes, make a PR against release branch and you'll need to include an explanation as to why you think this PR deserves to land, and you'll need approval from a `release-arbiter`. For now, Brandon will be the sole release arbiter, with the intention of introducing a program to ramp up others and set up a rotation for primary and secondary for a given release.

If the fix for some critical bug is too complicated, the offending commit, if it can be found, will be reverted. If neither of these things can happen, we'll miss our release and this should be considered *bad* and all hands on deck to fix.

During the period in which the release branch is open, any bugs assigned to you should be considered very high priority.

### Specifics

Release branch naming scheme is still in flux due to some issues with how deb repos think about versions. For now we'll use the following format:

```
release/0.0.x-beta
```

Where `x` is replaced with the number of the release (one-indexed). For example, on 8/7 we will cut `release/0.0.3-beta` after code freeze.

Releases will typically be deployed the night before a release (for now, Monday @ 6pm). If the builds are all successful and one can connect to that network we'll move forward using that as this week's testnet.

### Schedule

For now, we'll plan on releasing every Tuesday @ 2pm, starting on 8/6

#### Next week: (week 4 july)

- Tuesday morning, move `master -> develop` and `stable -> master`
    - This also entails fixing whatever tooling we have in place to point to the new branches, and updating the configuration of our documentation so the edit-button points to develop branch
- Cut the new `release/*` branch on EOD Monday (Tuesday morning), and have a testnet candidate online by Tuesday afternoon
    - This is earlier than "usual" as we haven't tested master in a few weeks

#### Other weeks:

- Cut the new `release/*` branch @ 2pm Wednesdays — with an intention to push to Thursday as we improve automation around our QA process.

### Website, Bots, and other products

- Static Website will be deployed off of `develop` eventually we can move to continuous deployment there as well.
- Bots (echo service and faucet) should be coupled to the release and therefore should be moved to the mono-repo
    - This doesn't need to happen next week though
- We can consider other products' lifecycles whenever they are released

### Environments

TODO post discussion with Conner and Joel, not as high priority as everything else on this document.

### Git Flow

Git flow is a branching/workflow model for using git. It is focused around managing and maintaining project releases and hotfixes. It is a standard around branch names, base branches, and how certain branches are merged.

#### CLI

There is a handy CLI for git flow that helps automate steps in the workflow. It is recommended, but not required. [https://github.com/nvie/gitflow](https://github.com/nvie/gitflow)

#### Description

At it's core concept, a git flow repository has two "source branches" (branches which are always open and are never merged into other branches). First, there is the `master` branch, which no longer is where fresh development goes, but rather is a source of truth for stable code which is deployed to a public environment. The primary branch which development is done off of is the `develop` branch. Git flow categorizes all other branches into 3 types: work branches, hotfix branches, and feature branches.

#### Work Branches

A work branch is any branch that is not a release branch or a hotfix branch. The prefix for these branches is slightly arbitrary, but common prefixes (which we already use) are `feature/*` and `fix/*` (it is typically bad practice to have too many prefixes). A work branch can be cut from any branch *except* for the `master` branch (which can only have hotfixes cut from it). The workflow for a work branch is pretty much what you would expect: cut from a branch, do your work, then PR it back into the branch you cut from.

#### Release Branches

A `release/*` branch represents a candidate for a release. It is cut off of `develop` and staging environments are deployed off of it in order to validate the release. If minor issues are found with the release branch, a `fix/*` branch is cut from the release branch and is PR'd back into the release branch. If major issues are found with the release branch, then the work that caused the regression is reverted in `develop`, and the release branch is recut from `develop`. When a release branch is ready for release, it is simultaneously merged into both `master` and `develop`, ensuring that the new commits go into the stable view of released code, and any fixes that needed to be done while validating the release make it back into the active development branch. At this point, the deployment team would deploy off of the code in `master`.

#### Hotfix Branches

A `hotfix/*` branch represents a high priority fix that needs to be released outside of the regular release cadence. Hotfix branches are sort of like the inverse of a release branch; they are cut off of `master` and merge into both `master` and `develop` once they are finalized. Typically, a hotfix branch would be deployed to a staging environment and tested before it is merged and deployed to production.

#### A Note on Merges

As a standard, we typically squash our commits when we merge branches. Under gitflow, we can continue to do this for work branches, but hotfix and release branches *must* be merged the traditional git way. Git flow only works if the commits in `master` and `develop` associated with some diff have the same SHAs (i.e. the commits between the two branches are always shared, so history is available for proper merging). Luckily, the git flow command line automates much of the details of dealing with hotfix and release branches, so it's not hard, but the key thing here is that you do *not* create PRs and squash merges for hotfix and release branches.

#### Learn More

The original blog that git flow was standardized from: [https://nvie.com/posts/a-successful-git-branching-model/](https://nvie.com/posts/a-successful-git-branching-model/)

A decent tutorial on how to use the git flow CLI: [https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

## Drawbacks
[drawbacks]: #drawbacks

It's a big change to our workflow.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

### Why not X

*When X = Do this crazy thing instead of just keep master stable and deploy frequently*

We'll always need a stabilization period where we prepare for a release and fix critical issues that come up — even if (when) we automate most things. The automation can only go so fast, so we won't be able to do it every commit, and I don't think we can automate everything — we'll need human(s) to QA, esp. in the short term

*When X = Do everything on master and cherry-pick into a release branch*

This isn't conducive to a universe in which we have more than one release at once — we already have one. We have the existing testnet and we have the stabilization of the next release of the testnet — in the future we'll have the mainnet, and probably several testnets.

## Prior art
[prior-art]: #prior-art

Git flow which we are picking and the approaches described above.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Details around environments

