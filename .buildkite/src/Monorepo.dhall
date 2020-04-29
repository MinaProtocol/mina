let Prelude = ./External/Prelude.dhall

let Command = ./Lib/Command.dhall
let JobSpec = ./Lib/JobSpec.dhall
let Pipeline = ./Lib/Pipeline.dhall

let jobs : List JobSpec.Type = [
  ./jobs/Sample/Spec.dhall,
  ./jobs/Sample2/Spec.dhall
]

let prepareCommand = "./.buildkite/scripts/generate-diff.sh > computed_diff.txt"

let makeCommand = \(job : JobSpec.Type) -> ''
  if cat computed_diff.txt | grep -q ${job.dirtyWhen}; then
      dhall-to-yaml --quoted <<< './.buildkite/src/jobs/${job.name}/Pipeline.dhall' > pipe.yml
      buildkite-agent pipeline upload pipe.yml
  fi
''

let commands = Prelude.List.map JobSpec.Type Text makeCommand jobs

in Pipeline.build Pipeline.Config::{
  spec = JobSpec::{ name = "monorepo-triage", dirtyWhen = "" },
  steps = [ Command.Config::{command = [ prepareCommand ] # commands, label = "Monorepo triage", key = "cmds", target = <Large | Small>.Small} ]
  }

