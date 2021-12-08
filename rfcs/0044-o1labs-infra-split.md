## Summary
[summary]: #summary

Move O(1) Labs-specific infrastructure from the Mina repository to a
separate, infra-specific repository.

## Motivation
[motivation]: #motivation

O(1) Labs uses Infrastructure as Code (IaC) for its Mina-related
infrastructure. This means that the deployments are declaratively
specified in code, and that code tracked in git.

IaC is well-regarded in the industry as a best practice, since it
helps the Operations team to better track, maintain and recreate the
existing deployments, and speeds up new ones.

However, in its current form, Mina's approach to IaC limits the
benefits. One of problematic design decisions is that all the
infrastructure code resides in a giant monorepo with a slow release
cadence. Here are some issues which arise because of this:

- Deployments are oft performed from arbitrary branches, so it's not
  trivial to figure out which deployment came from where. This often
  makes it difficult to maintain or redeploy;
- Deployments don't get updated when the branch head moves, leaving
  them "hanging". This can be confusing for people working on
  bugfixes, since the apparently fixed bug can be reproduced on the
  (outdated) deployment;
- Repository is bloated with code that is not at all relevant for
  outside collaborators. This may scare off some potential contributors.

## Detailed design
[detailed-design]: #detailed-design

As noted in [summary](#summary), the proposal is to move some code
from the Mina monorepo to a separate, O(1) Labs specific repository.

The new repository should probably be public to keep transparency with
the community and provide examples for other people wishing to deploy
their own infrastructure.

The criteria to decide whether to leave some part of infrastructure
code in the main Mina repository or to move it into the new, separate
repository, is as follows:

1. Can the code in question be directly used (ran, deployed, etc) by
   people unaffiliated with O(1) Labs?
2. Is the code in question possible to separate without significantly
   impacting the functionality?

The code should be moved to the new repository when both criteria are
true. The second criterion is a compromise, appended to prevent this
RFC exploding in scope to a total infrastructure refactoring. In some
cases, where the refactoring is trivial (e.g. simply splitting up
existing code into modules), this refactoring may be performed.

It should also be thoroughly documented, together with clear
instructions on deploying testnets and running cloud-based integration
tests from the new repository (with a clear warning to always keep the
branches in the infra repository up to date with actual deployments,
and vice versa). As some future work, we may even require all
deployments to happen from CI, eliminating the possibility of
infrastructure state drifting from code entirely.

### The incomplete list of directories or files to be separated

_📝Note: the author of this RFC is not intimately familiar with the code
base, so this part needs to be extensively discussed with people who are_

_📝Note: This list is deliberately incomplete to prevent the RFC from
becoming its own implementation, and is likely to be amended during
the implementation phase_

- `automation/`: Appears to only be useful for O(1). Seems
  to be somewhat difficult (but possible) to separate since it is
  coupled to the helm charts. Separation will probably require some
  form of pinning for the Mina repository, such as a git submodule.

### Debatable "keeps"

- `buildkite/`: Not trivial (but possible) to use for outsiders;
  perhaps useful for CI in forks? Also, really difficult to separate,
  since it appears to be somewhat coupled to the actual code the CI is
  building;
- `helm/`: Definitely possible to use by outsiders, quite difficult to
  separate. However, if it is easier to move it to the infrastructure
  repository together with the coupled terraform, we may do that as a
  compromise.

## Drawbacks
[drawbacks]: #drawbacks

- (obvious) The split is going to take some amount of work. It is
  currently not clear how much exactly, so we need to consider this
  and compare it to the potential benefits.
- Monorepo has some advantages: all the code is in the same place,
  there is no need to manage cross-repo dependencies or keep a mental
  image of what parts go where.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- (obvious) Do nothing. This has the benefit of not taking up any
  work, but we are left with all the issues specified in [motivation](#motivation);
- Move the O(1)-specific infrastructure to a clearly separated folder
  in the monorepo. This has the benefit of not having to cross-repo
  pin, but leaves the issues with messy git branches and deployments;
- Make up some rules about git and deployment discipline, and enforce
  them either technically or socially. This may be easier to
  implement, but harder to maintain, since rule enforcement tends to
  drift with time.

## Prior art
[prior-art]: #prior-art

Apparently, Mina started out with many fragmented repositories, and
then moved towards a monorepo. The author of RFC is not familiar with
Mina's history, so the reasoning and motivation behind this decision
are unclear. Perhaps some lessons should be taken from the
pre-monorepo times.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Where exactly to draw the line between code that's being split and
  code that's left in the monorepo;
- (future work) Whether forcing all deployments to happen from CI is worth it.
