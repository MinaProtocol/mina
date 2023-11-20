# Buildkite baseline
`test-drive` proposes a set of very simple sample pipelines, in which the goal is to leverage Dhall for reducing boilerplate code, as well as to unify CI under Buildkite.

- `python`: example for running Python workflows.
- `dynamic`: creates a dynamic pipeline. It reacts to changes to `python/test.py`