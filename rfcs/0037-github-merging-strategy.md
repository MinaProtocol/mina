## Summary
[summary]: #summary

This RFC proposes changing our git merge strategy from squash to merge commits.

## Motivation
[motivation]: #motivation

We would like for pull-requests (PRs) to merge more quickly and automatically.
We would also like to encourage smaller PRs, to reduce the burden on reviewers
and to reduce the amount of work that has to be done keeping up with upstream
changes in the `develop` branch.

In addition, we have begun to use GitHub's 'PR chains', where a series of
smaller changes can be linked together in a chain, but with each change in its
own PR. These allow us to continue to work on larger features even when
earlier changes haven't yet been included in the `develop` branch, and without
combining the changes into a single large PR.  PR #5093 added support for the
`ready-to-merge-into-develop` label, which automates the process of merging
these PR chains correctly.

When multiple PRs modify the same lines of code and one of them is merged into
`develop`, the other will have 'merge conflicts' and will need manual
intervention to fix the conflict before it can be merged. We would like to
minimise this because
* PRs with conflicts do not merge automatically
* the PR process is slowed down by waiting for these manual interventions
* developer time is wasted in resolving these conflicts.

Our current merge strategy is 'squash and merge', which discards the
individually committed changes within each PR. This hampers `git`'s ability to
reduce or eliminate merge conflicts by combining the changes from individual
commits, unnecessarily creating more merge conflicts to be handled manually.

These unnecessary conflicts are particularly prevelant in PR chains. For
example,
```
PR 1
   develop
-> [Add line 1 in A.txt]
-> [Modify line 1 in B.txt]

PR 2 (chained to PR 1)
   develop
-> [Add line 1 in A.txt]
-> [Modify line 1 in B.txt]
-> [Modify line 1 in A.txt]
-> ...
```
when `PR 1` is squashed and merged into develop, `git` is unable to recognise
that the initial changes made in `PR 2` match with those from `PR 1` and
reports a merge conflict.

If PRs in chains have review comments that result in changes, these will
usually also result in a merge conflict. For example,
```
PR 1
   develop
-> [Add line 1 in A.txt]
-> [Modify line 1 in B.txt]
-> [Modify line 1 in A.txt in response to review comments]

PR 2 (chained to PR 1)
   develop
-> [Add line 1 in A.txt]
-> [Modify line 1 in B.txt]
-> [Add line 1 in C.txt]
-> ...
```
when `PR 1` is squashed and merged, `git` will again be unable to merge `PR 2`
automatically.

## Detailed design
[detailed-design]: #detailed-design

We can use `git`'s merge commits when merging to avoid the above issues. These
preserve the individual commit information that `git` needs to automatically
resolve these conflicts.

This is a simple configuration change in the GitHub settings for the repo.

## Drawbacks
[drawbacks]: #drawbacks

#### We lose a linear `git` history (from `git log` and friends)

Locally, developers can use `git log -m --first-parent` to view only the merge
commits. `git log -m --first-parent --patch` shows the changes from commits
beneath the merge commit, as expected.

To generate a linear history from any branch between commits `aaaaaa` and
`ffffff`, run the commands
```bash
git checkout aaaaaa
for commit_id in $(git rev-list --reverse --topo-order --first-parent aaaaaa..ffffff); do
  git read-tree $commit_id && git checkout-index -f -a && git update-index -q --refresh && git commit --no-verify -a -C $commit_id;
done
```

#### `git blame` identifies the commit within PRs instead of the merge commit

Similar to the above, developers can locally use `git blame -m --first-parent`,
or blame on the 'prettified' branch.

#### `git bisect` will explore some non-merge commits

We can set `git bisect` to ignore any non-merge commits by running a script
`bisect-non-merge.sh bad_commit good_commit` with

```bash
#!/bin/bash
set -euv
git bisect start $1 $2
git bisect skip $(git rev-list --no-merges $2..$1)
```

To include commits from before the switch from squash to merge, this can be
modified to

```bash
#!/bin/bash
set -euv
git bisect start $1 $2
git bisect skip $(git rev-list --no-merges ^ffffff $2..$1)
```

where `ffffff` is the last commit where we used the squash merge strategy.

##### Manual bisection

For any scripts where we want to implement bisect ourselves, we can instead use
`git rev-list --first-parent aaaaaa..ffffff` to get the full list of commits
from `aaaaaa` (non-inclusive) to `ffffff` that we want to bisect over.

#### The history will contain bad or useless commit messages

This can be mostly ignored when using the above mitigations. Changing commit
message culture is out of the scope of this RFC.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

* Why is this design the best in the space of possible designs?
  - The alternatives (squashing and rebasing) both throw away the information
    that `git` needs to handle merges most effectively.
* What other designs have been considered and what is the rationale for not choosing them?
  - Squashing and rebasing, as above.
* What is the impact of not doing this?
  - Slower, manual PR merging and wasted developer effort.

## Prior art
[prior-art]: #prior-art

`git` was designed with merges using these kinds of merge commits in mind. The
Linux kernel has used merge commits since it switched over to `git` in 2005.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* What parts of the design do you expect to resolve through the RFC process before this gets merged?
  - None
* What parts of the design do you expect to resolve through the implementation of this feature before merge?
  - None
* What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
  - Commit message culture.
