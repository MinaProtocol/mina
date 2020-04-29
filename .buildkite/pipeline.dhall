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
  ./.buildkite/src/jobs/Sample/Spec.dhall,
  ./.buildkite/src/jobs/Sample2/Spec.dhall
]

let makeCommand = \(job : { dirtyWhen : Text, name : Text }) ->
"if ./.buildkite/scripts/generate-diff.sh | grep -q ${job.dirtyWhen}; then dhall-to-yaml --quoted <.buildkite/src/jobs/${job.name}/Pipeline.dhall | buildkite-agent pipeline upload; fi"

let List/map = https://prelude.dhall-lang.org/v15.0.0/List/map

let commands = List/map JobType Text makeCommand jobs

in  { steps = [ Command::{command = commands, label = "Triage dirty", key = "triage"} ] }

