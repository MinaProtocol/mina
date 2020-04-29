let Command =
      { Type =
          { command : List Text
          , label : Text
          , key : Text
          }
      , default = {=}
      }

let JobType = { dirtyWhen : Text, name : Text }

let jobs : List JobType = [
  ./src/jobs/Sample/Spec.dhall,
  ./src/jobs/Sample2/Spec.dhall
]

let diff = "git diff $(diff -u <(git rev-list --first-parent $BUILDKITE_PULL_REQUEST_BASE_BRANCH) <(git rev-list --first-parent $BUILDKITE_BRANCH) | sed -ne 's/^ //p' | head -1) --name-only"

let makeCommand = \(job : { dirtyWhen : Text, name : Text }) ->
"if ${diff} | grep -q ${job.dirtyWhen}; then \"dhall-to-yaml --quoted <.buildkite/src/jobs/${job.name}/Pipeline.dhall | buildkite-agent pipeline upload\"; fi"

let List/map = https://prelude.dhall-lang.org/v15.0.0/List/map

let commands = List/map JobType Text makeCommand jobs

in  { steps = [ Command::{command = commands, label = "Triage dirty", key = "triage"} ] }

