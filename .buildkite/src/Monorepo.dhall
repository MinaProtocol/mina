let Prelude = ./External/Prelude.dhall

let Command = ./Lib/Command.dhall
let JobSpec = ./Lib/JobSpec.dhall
let Pipeline = ./Lib/Pipeline.dhall
let Size = ./Lib/Size.dhall

let jobs : List JobSpec.Type = ./Jobs.dhall

-- precompute the diffed files as this command takes a few seconds to run
let prepareCommand = "./.buildkite/scripts/generate-diff.sh > computed_diff.txt"

-- Run a job if we touched a dirty path
let makeCommand = \(job : JobSpec.Type) -> ''
  if cat computed_diff.txt | grep -q ${job.dirtyWhen}; then
      dhall-to-yaml --quoted <<< './.buildkite/src/jobs/${job.name}/Pipeline.dhall' | buildkite-agent pipeline upload
  fi
''

let commands = Prelude.List.map JobSpec.Type Text makeCommand jobs

in Pipeline.build Pipeline.Config::{
  spec = JobSpec::{
    name = "monorepo-triage",
    -- TODO: Clean up this code so we don't need an unused dirtyWhen here
    dirtyWhen = ""
  },
  steps = [
    Command.Config::{
      command = [ prepareCommand ] # commands,
      label = "Monorepo triage",
      key = "cmds",
      target = Size.Small
    }
  ]
}

