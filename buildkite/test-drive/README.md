# Buildkite baseline
`test-drive` proposes a set of very simple sample pipelines, in which the goal is to leverage Dhall for reducing boilerplate code, as well as to unify CI under Buildkite.

Currently, there are two different PoC:
- `python`: example for running Python workflows.
- `dynamic`: creates a dynamic pipeline. It reacts to changes to `python/test.py`

## Reasons to invest time in Dhall
1. **Codebase is solid**. there is a lot of work already done to support complex CI pipelines, such as those used to generate Mina artifacts. No other solution could win enough terrain in sufficient time as to equal what is already achieved with Dhall.
2. **Simple and with good documentation.** In contrast with other alternatives, such as [CUElang](https://cuelang.org), Dhall is human-friendly and its qualities purposefully though-through as to be secure and have constant execution time. Albeit with a not as active community as Cue's, Dhall is very well [documented and supported](https://github.com/dhall-lang/dhall-lang/tree/master).


## Main issues to be resolved
1. **A lot of tech debt**. The `Prelude` library, which is sort of Dhall's standard library, is currently in version `v23.0.0`, while we are using `v15.0.0`.
2. A definition of a SDLC for each package to be delivered is necessary. This workflow may include conditionals and other considerations, but in order to take full advantage of current scaffolding **we need a set of use cases in which to develop on**.


## Current outputs
### Static `python` pipeline PoC
This PoC develops a [basic pipeline](https://github.com/MinaProtocol/mina/blob/lsanabria/buildkite-test-drive/buildkite/test-drive/python/pipeline.yaml). It simply tries to execute a Python script using a community container.
### Dynamic pipeline PoC
It reuses the `python` pipeline, but instead of explicitly introduce it into the Buildkite steps, it will be dynamically built by the Buildkite agent from `dhall-to-yaml`. The command is executed on an ["orchestrating" pipeline](https://github.com/MinaProtocol/mina/blob/lsanabria/buildkite-test-drive/buildkite/test-drive/dynamic/pipeline.yaml). Consequently, the [generated pipeline](https://github.com/MinaProtocol/mina/blob/lsanabria/buildkite-test-drive/buildkite/test-drive/dynamic/Test.dhall) is executed.

This structure is what is thought to define monolithic dynamic pipelines. That is, a tree is being built, where each fork leads to the execution of a particular pipeline. In turn, each fork is a consequence of a check, e.g., branch name, origin repo, or whatever condition involved in the SDLC.

This has been [successfully tested](https://buildkite.com/o-1-labs-2/test-pipeline/builds/208) in Buildkite.