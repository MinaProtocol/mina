# Contributing to Coda

Thank you for your interest in contributing to Coda 😁. This file outlines
various parts of our process. Coda is still very young, so things might be a
little bumpy while we figure out how to smoothly run the project!

## Bug reports

Bug reports should include, at minimal, the `coda -version` output and
a description of the error. See the `.github/ISSUE_TEMPLATES/bug_report.md` file
for the template used.

All bugs need to be reproduced before they can be fixed. Anyone can try and
reproduce a bug! If you have trouble reproducing a bug, please comment with what
you tried. If it doesn't reproduce using exactly the steps in the issue report,
please write a comment describing your new steps to reproduce.

Maintainers should label bug reports with `bug`, and any other relevant labels.

## Feature requests

We'll consider any feature requests, although the most successful feature
requests usually aren't immediately posted to the issue tracker. The most
successful feature requests start with discussion in the community!

Maintainers should label feature requests with `feature`, and any other relevant
labels.

## Pull Requests

All pull requests go through CircleCI, which makes sure the code doesn't need to
be reformatted, builds Coda in its various configurations, and runs all the
tests.

All pull requests must get _code reviewed_. Anyone can do a code review! Check
out the [code review guide](CODE_REVIEW.md) for what to look for. Just leave
comments on the "Files changed" view.

All pull requests must be approved by at least 2 maintainers. Maintainers should
assign reviewers to pull requests, and tag them with any relevant labels.

## Maintainership

The maintainers are the people responsible for making sure the project runs
smoothly and that the software is held to a high standard of quality.
Responsibilities include code review, issue management, etc. You could be a
maintainer someday! We haven't decided how to handle this yet, but in general
maintainers will already have an established history of being generally helpful,
whether that comes to issue triage and followup, code reviews, bug fixes,
documentation changes, etc.

## Documentation

There are two main pieces of Coda documentation:

1. The `docs` directory, which has prose documentation of various sorts. This
   doesn't exist yet, but it should by the time this repo is made public!
2. Inline code comments. There are very few of these, and we don't run ocamldoc
   anyway.

Changes to the software should come with changes to the documentation.

## RFCs

The `rfcs` directory contains files documenting major changes to the software,
how we work together, or the protocol. To make an RFC, just copy the
`0000-template.md` to `0000-shortname.md` and fill it out! Then, open a pull
request where the title starts with `[RFC]`. The idea is that we can discuss the
RFC and come to consensus on what to do. Not all RFCs are merged, only the ones
that we agree to implement. There is very little formal process around this
right now.

This is loosely inspired by the Rust RFC process, Python PEPs, and IETF RFCs.

## Issue/PR label guide

We use them, although currently in a somewhat ad-hoc way. Please see
https://github.com/CodaProtocol/coda/labels for the list of labels and their
short descriptions. Any "complicated" labels should be described here.
