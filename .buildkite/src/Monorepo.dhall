let Prelude = ./External/Prelude.dhall

let Command = ./Lib/Command.dhall
let Docker = ./Lib/Docker.dhall
let JobSpec = ./Lib/JobSpec.dhall
let Pipeline = ./Lib/Pipeline.dhall
let Size = ./Lib/Size.dhall
let triggerCommand = ./Lib/TriggerCommand.dhall

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
      command = commands,
      label = "Monorepo triage",
      key = "cmds",
      target = Size.Small,
      docker = Docker.Config::{ image = (./Constants/ContainerImages.dhall).toolchainBase }
    }
  ]
}

