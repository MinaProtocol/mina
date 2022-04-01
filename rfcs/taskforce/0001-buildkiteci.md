# BuildKite CI Switch

===

# Goal

## Relevant Problems

- CircleCI is expensive because it's hosted (P1)
- Slow builds (P2)
  - Our configuration is not scheduled optimally — this leads to slower builds than are actually possible (P2.1)
    - Parallelism is not granular but rather just at the outskirts (P2.1.1)
    - Test execution doesn't share artifacts before fanning out (P2.1.2)
  - Instances are not as large as we'd want them to be (even at the "largest" size) (P2.2)
  - Test execution is not granular (P2.3)
- Requires a manual template expansion step (test.py) (P3)
- Iterating on builds requires running things on our existing build infrastructure (P4)
- Flaky tests don't have a good story ;; It isn't clear which tests are truly "flaky and we want to ignore the flake" and this failure is important to look at (P5)
- Nix builds don't work in CircleCI's infrastructure anymore (P6)

## Impact of this project

Intended to solve or set up infrastructure for enabling solving all of the above
friction points.

# Design

## Existing System

We run the following sorts of jobs:

1. Linting
2. Non-consensus / Consensus compatibility
3. Trace tool
4. Update branch protection on GitHub (only on develop)
5. Building the wallet + bots (macos)
6. Building the website (macos)
7. Archive nodes
8. Build daemon (macos)
9. Build client-sdk
10. Artifact build
11. Unit tests
12. Nonconsensus unit tests
13. Various integration tests
14. Nightly builds with larger configurations that we don't pay attention to

The longer builds are unit tests (30min !!!) and integration tests (~20min average ;; 8min is just the build). The artifact medium curves build (~45min !!!)

### Breakdown of longest job (build-artifacts-medium-curves)

1. Pinning opam packages ~2m
2. Generate PV keys (build part1) ~5m30s
3. Rebuild for PV keys changes (build part2) ~5m10s
4. Generate runtime genesis ledger ~3m30s
5. Build deb package ~2m30s
6. Upload deb to repo ~1m30s
7. Docker build and publish ~20m (!!!)

## Details

Mac machines are a pain to manage ourselves. For our mac jobs, keep using CircleCI.

For everything else, switch to [BuildKite](https://buildkite.com)

### Why Buildkite

- Very good UI/UX around builds
- Easy-to-install Agent model, so very easy to run agents on variety of hardware including cloud, local machines (for testing purposes) — includes first-party Helm charts for trivial deployment with our infrastructure
- First-class artifact upload/download with GCP cloud storage
- Dynamic pipelines allow dynamic reconfiguration of builds from builds themselves — this can be used for expanding work based on files touched and support generated YAML
- Healthy ecosystem of plugins [https://buildkite.com/plugins](https://buildkite.com/plugins)
- Supports direct encoding of dependency graph of jobs
- Run buildkite agents locally or on manually spun up compute instances to test rules by targeting specific agents with tags and using the CLI [https://github.com/buildkite/cli](https://github.com/buildkite/cli)
- Brandon has extensive experience working with BuildKite at Pinterest (and with a few side projects); lower risk

## Details

### Deploying of Nodes

Deploy agents with a helm chart on k8s — same as the rest of our infrastructure [https://github.com/buildkite/charts](https://github.com/buildkite/charts). It sets a service account so we can still build docker images and use kubectl and helm during pipelines.

Engineers who are iterating on build rules can run nodes locally or spin up instances to test things using the buildkite CLI

### Description of pipelines

Pipeline are configured with Dhall rather than jinja-templated yaml. Dynamic pipelines support this as a first-class citizen, we do not require running the equivalent "`test.py`" before pushing. I have already implemented this on a [side project](https://github.com/bkase/gameboy/blob/master/.buildkite). Notice that there is a small `pipeline.yaml` to bootstrap the `pipeline.dhall` -- `pipeline.dhall` is rendered at _build_ time, not commit time.

**General Pipeline Writing Things**

- Use something like the [BuildKite monorepo plugin](https://github.com/chronotc/monorepo-diff-buildkite-plugin) for granular test execution. This is easy to implement with BuildKite's dynamic pipelines as described above.
- Explicitly opt-in to the dependency graph. Don't support the "wait" instruction that blocks all parallel work.

Assuming this proposal is accepted, more details will follow on how to structure the Dhall descriptions, but here is a rough cut of what it could look like:

```haskell
-- This is a definition of the package-deb step for Coda
-- Optional decorations stack on top of the required bits
-- This step will rerun twice before giving up
-- It will upload artifacts under /tmp/artifacts/** to google cloud
-- It depends on coda-build, genesis-ledger, and libp2p-helper steps
-- Then the 4 required fields are given: a nice label for the UI, the
--   command to run, a machine-readable key for further dependency graph
--   manipulation, and a list of globs for granular test execution.
-- Note: By making dirtyWhen a _required_ field, we set ourselves up for
--       a world in which CI doesn't run on docs changes
let packageDebStep =
   decorate3
	   (withFlaky 2)
	   (withArtifacts "/tmp/artifacts/**")
		 (withDeps [ "coda-build", "genesis-ledger", "libp2p-helper" ])
	   Command::{
	     label = ":box: Package deb",
	     command = "make deb"
	     key = "package-deb",
	     dirtyWhen = [ "src/**" ]
	   }
```

### Workflow of adding/changing/debugging pipelines

Run buildkite agents locally or on manually spun up compute instances to test rules by targeting specific agents with tags and using the CLI [https://github.com/buildkite/cli](https://github.com/buildkite/cli)

Liberal use of artifact uploading/downloading to keep build re-playable from different steps and allow build artifacts to be reused in more pipelines.

## This design solves the above issues

P1 → self-hosted on GKE

P2.1.1 → Parallel by default; opt-in to dependencies

P2.1.2 → Rely on artifacts in gcloud which should be very quick to upload and download from within Gcloud infrastructure

P2.2 → We can choose whatever machines we want

P2.3 → We use dynamic pipelines to expand work based on files touched

P3 → Manual adhoc template expansion is replaced with [automatic](#description-of-pipelines) expansion using Dhall

P4 → BuildKite agents can be installed and tagged locally (or on your own instances) to iterate on builds on your own hardware before putting it into production

P5 → Flakiness is explicit in the Dhall configuration

P6 → Nix builds work inside docker containers "on my machine" so there is no evidence that they won't work on gcloud.

## Mapping of resource utilization to tasks

Big machines — 8core, 30GB of RAM

- Builds
- Heavy integration tests
- All unit tests

Light machines — 1core, 3.75GB of RAM

- Linting
- Small tools
- (when we break up unit tests)

## Projected Spend

We can run 20 Big machines for ~80% of what we're paying circle per month even if these 20 machines were on 100% of the time and not preemptible.

This will also become much cheaper when we do autoscaling or if we use preemptible instances and support retries in case of preempt failure.

If necessary we can look into getting this system to work on Azure to make better use of our credits, but Buildkite works much better with Gcloud and/or Aws. Azure credits will be easily used up by compute nodes during QA-net debugging.

## Rough plan of moving over

Work can be parallelized across working on the deploy infrastructure, pipeline creation, artifact management work

1. Start with a super easy job (lint)
2. Enable on both Circle and Buildkite and disable on circle only after 3 working days of PRs
3. Move over a very high impact job — build-artifacts-medium-curves + all dependencies. Parallelize the crap out of it and set us up to reuse artifacts for other jobs.
4. Put in the new integration tests (blocked on implementing the new integration tests)

=== This is the point at which we can stop for task force (or maybe we'll want 5) ===

5. Split unit tests into more granular parallel jobs

6. Use pre-emptible instances

7. Auto-scaling

8. Move the rest of the work over other than mac builds

9. Handling mac builds ourselves either with an in-house mac machine or with mac in a data center

## Support for external contributors

With build machines running on our infrastructure we need to be careful about
running arbitrary code from others. Thanks @yourbuddyconner for flagging this
one.

In order to keep our systems safe, CI should not start immediately for non-core
team members but rather only start when a core team kicks off the build. This
can be triggered initially by a step in buildkite, and later move to a bot in
GitHub.

The nice thing about this approach is we no longer need to support a
"second class" version of the build for non-core team members that disables
access to necessary secrets. We can assume all builds have access to all
variables.

Core team reviewers will of course need to double check to see if any secrets
are trying to be exfiltrated or our infrastructure is attempting to be
compromised before granting permission for CI to run.

## Explicitly NOT in scope for this project

- Autoscaling
- Granular test execution beyond Project level granularity
- Retooling _how_ builds work
  - Incremental builds
  - Retooling of docker toolchain
  - Changing the manner in which builds and tests are executed (ie touching how dune is configured)
    - Changing the Docker upload step; through this investigation that has been identified as a high-impact potentially low hanging fruit thing to fix
- Supporting pre-emptible instances with retries
- Retooling unit tests

## Alternatives Considered

**Stick with Circle, rewrite config.yml with Dhall**

Pros:

- Less work
- P2.1 can be solved this way

Cons:

- Most problems not easily solvable without more engineering effort than their equivalent solutions in buildkite

# Outstanding Questions

- Are there any details here that aren't fleshed out enough?

- Brandon has set up buildkite on remote macos machines and locally on his laptop, but has not deployed instances on cloud infrastructure before. Does anyone see any issues with that in particular?

# Epic Link

Issue #4762
