# Contributing to Mina

Mina is an open source project. Thank you for your interest in contributing to Mina. This file outlines
various parts of our process. Mina is always evolving and in active development, so things might be a
little bumpy while we work together to provide the best experience for you to contribute!

See the [developer README](README-dev.md) for the
basic setup you need to get up and running to build and edit Mina.

Here's the summary if you want to contribute code:

1. Learn some OCaml. The [Real World OCaml](https://dev.realworldocaml.org/toc.html) book is good. Jane Street also has [some exercises](https://github.com/janestreet/learn-ocaml-workshop).
2. Learn how we use OCaml, see the [style guide](https://docs.minaprotocol.com/node-developers/style-guide) that goes over the important things. 
3. Fork and clone the repo, then set up your development environment. See the [Mina README-dev](README-dev.md) for details.
4. Find a good first issue. The best issues to start with have the [`easy`](https://github.com/MinaProtocol/mina/labels/easy) label.
5. Create a branch in your local clone and implement the solution.
6. Push the branch to your GitHub fork and create a pull request.
7. 🙌

## Bug reports

Bug reports must include, at minimal, the `mina -version` output and
a description of the error. See the [bug report
template](.github/ISSUE_TEMPLATE/1-BUG_REPORT.yml). Report documentation
issues and failing tests using those issue templates.

All bugs need to be reproduced before they can be fixed. Anyone can try and
reproduce a bug. If you have trouble reproducing a bug, please comment with what
you tried. If it doesn't reproduce using exactly the steps in the issue report, 
write a comment describing your new steps to reproduce or what environment
setup you had to do to reproduce.

Code maintainers must label bug reports with `bug` and all other relevant labels.

## Feature requests

We'll consider any feature requests, although the most successful feature
requests usually aren't immediately posted to the issue tracker. The most
successful feature requests start with discussion in the community!

Maintainers label feature requests with `feature` and other relevant
labels.

## Pull Requests

### Branching workflow

Make sure to read about the [branching workflow](README-branching.md) to
understand on which branch (`compatible` or `develop`) to work in
and how to manage simultaneous PRs to both branches.

### Continuous integration

All pull requests go through Buildkite CI to make sure the code doesn't need to
be reformatted, builds Mina in its various configurations, and runs all the
tests.

All pull requests must get _code reviewed_. Anyone can do a code
review! Check out the [code review
guide](https://docs.minaprotocol.com/node-developers/code-review-guidelines) for
what to look for. Just leave comments on the **Files changed** view.

All pull requests must be approved by at least one _code owner_ for the
source code they touch. See the [CODEOWNERS](./CODEOWNERS) file to
find out who the maintainers are.

Maintainers assign reviewers to pull requests and tag the pull requests with 
relevant labels. If you happen to have access to the development Slack,
you can skip this step by asking reviewers directly in the #review-requests channel.

- If you are PRing from the main remote branch, add the **ci-build-me** label when you want to run CI. 
- If you are PRing from a fork, ask a core contributor to add the `!ci-build-me` comment to your PR when you're ready for CI to run. 

**Note:** The `!ci-build-me` comment is required for each and every run of CI.

After a PR has been reviewed and approved and all CI tests have passed, the PR can be merged
by a maintainer (or by you, if you have this access).

If you encounter problems with the CI, read [CI FAILURES](README-ci-failures.md)
for common troubleshooting steps.

## Documentation

There are three main pieces of Mina documentation:

1. The [https://github.com/o1-labs/docs2)](https://github.com/o1-labs/docs2) repository for the [Mina Protocol](https://docs.minaprotocol.com/) docs website.
2. The `README.md` files in various directories explain the contents of that
   directory at a high level: the purpose of the library, design constraints, anything else
   specific to that directory.
3. Inline code comments. We are working to provide more comments. We run `ocamldoc` and the generated 
   [OCaml package documentation](https://mina-docs.storage.googleapis.com/index.html) is browsable.

Changes to the software require changes to the documentation. The Mina Docs use a docs-as-code workflow to develop and publish product documentation using the same tools and processes as software code development. All user-impacting updates on the codebase require corresponding updates to the relevant documentation in the docs repo. See the [Docs Contributing Guidelines](https://github.com/o1-labs/docs2/blob/main/CONTRIBUTING.md). 

## RFCs

The [`rfcs`](rfcs/) directory contains files documenting major changes
to the software, how we work together, or the protocol. To make an
RFC, just copy the `0000-template.md` to `0000-shortname.md` and fill
it out! Then, open a pull request where the title starts with
`[RFC]`. The idea is that we can discuss the RFC and come to consensus
on what to do. Not all RFCs are merged, only the ones that we agree to
implement.

This process isn't final, but in general:

1. RFCs will be open for at least a week for discussion.
2. After discussion has slowed down or there is consensus, the core eng team
   will initiate a "Final Comment Period". This will include the core eng's
   "merge disposition" (merge/don't merge). The FCP comment must be based
   on information and arguments already present in the RFC thread. At the
   end of the FCP, the core eng team decides to do another FCP, leave the FCP
   state for continued discussion, or resolve the RFC by merging/closing
   (whichever the announced disposition was).

RFCs do not have to come with an implementation, and the RFC author isn't
required to implement the PR.

RFCs generally describe the design of a feature. As the code corresponding to
the RFC changes, the RFC should be updated to reflect the current state of the
code.

This RFC process is loosely inspired by the Rust RFC process, Python PEPs, and IETF RFCs.

## Release process

Create a PR to merge `master` into `testnet`. After that PR is approved by CI and checked in...

```
git checkout testnet
git tag testnet-v0.$WHATEVER_IS_NEXT
git push testnet-v0.$WHATEVER_IS_NEXT
```

We create a branch `release/X.X.X` for each new release. 
All of the changes that go into that release must be merged into the appropriate
release branch.

Create a PR to merge testnet into the current release branch. After that is
approved by CI and checked in...

```
git checkout stable
git tag v1.$WHATEVER_IS_NEXT
git push v1.$WHATEVER_IS_NEXT
```

And then do the steps again for `testnet`. Don't forget to deploy!

## Issue/PR label guide

We use labels to provide important content. See
https://github.com/MinaProtocol/mina/labels for the list of labels and their
short descriptions. Any "complicated" labels are described here.
