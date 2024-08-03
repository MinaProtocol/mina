# Summary
[summary]: #summary

Organize branches by categories of work using and standardizing prefixes.

# Motivation
[motivation]: #motivation

As our repository continues to grow, so will our number of branches. As we begin to move towards having branches for releases, release candidates, bug fixes, and new features, and rfcs, we will need the ability to quickly understand which of these categories a given branch falls into. On top of this, categorizing by prefix will allow us to separate name conflicts so that branch names will only conflict if the both the category and the name are the same.

# Detailed design
[detailed-design]: #detailed-design

Moving forward, all branch names, with the exception of master, will be prefixed by a category identifier. These branch names will all follow the format "<category>/<name>", where name is a description of what the branch actually contains.

These are the categories which branches will fall into:
- feature (a new feature to the codebase)
- fix (a bug fix of existing features)
- rfc (a new rfc to be discussed)
- release (a branch with the latest version of a specific release target)
- release-candidate (a branch for locking and testing a potential future release before we finalize it)
- tmp (for ad-hoc, temporary, miscellaneous work)

These branch categories can be extended as new types of branches are required. For instance, in the future, we may want to have "environment" branches, where pushing to an "env/..." branch will kick off some CI to deploy the code at that branch to an environment. For example: push "feature/some-experiment" to "env/testbed" to test it in a cluster in the cloud, or push "release-candidate/beta" to "env/staging" to test a release candidate for regressions.

# Drawbacks
[drawbacks]: #drawbacks

The main drawback will be the initial migration. We have many branches out in the wild that are not prefixed yet, so there may be some confusion while we begin to adopt the new branch naming scheme, and before we can finish cleaning up the old branches.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

I'm not aware of any alternatives for managing this. Releases are managed through version tags, but the release branches discussed here are really just a layer on top of that, intended to represent the latest version of a specific release cycle (version tags should still be used).

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- How should we manage the migration towards using these new branches? Should we do one mass branch renaming, or should we remove old branches over time, pruning them as we no longer need them?
