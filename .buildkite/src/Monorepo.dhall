let Prelude = ./External/Prelude.dhall

let Command = ./Command/Base.dhall
let Docker = ./Command/Docker/Type.dhall
let JobSpec = ./Pipeline/JobSpec.dhall
let Pipeline = ./Pipeline/Dsl.dhall
let Size = ./Command/Size.dhall
let triggerCommand = ./Pipeline/TriggerCommand.dhall

let jobs : List JobSpec.Type = ./gen/Jobs.dhall

-- Run a job if we touched a dirty path
let makeCommand = \(job : JobSpec.Type) ->
  let trigger = triggerCommand "src/jobs/${job.name}/Pipeline.dhall"
  in ''
    if cat $computed_diff.txt | egrep -q '${job.dirtyWhen}'; then
        echo "Triggering ${job.name} for reason:"
        cat $computed_diff.txt | egrep '${job.dirtyWhen}'
        ${trigger}
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
      commands = commands,
      label = "Monorepo triage",
      key = "cmds",
      target = Size.Small,
      docker = Docker::{ image = (./Constants/ContainerImages.dhall).toolchainBase }
    }
  ]
}

