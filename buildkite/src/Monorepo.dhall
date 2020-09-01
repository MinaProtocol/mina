let Prelude = ./External/Prelude.dhall
let List/map = Prelude.List.map

let SelectFiles = ./Lib/SelectFiles.dhall
let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall
let Docker = ./Command/Docker/Type.dhall
let JobSpec = ./Pipeline/JobSpec.dhall
let Pipeline = ./Pipeline/Dsl.dhall
let Size = ./Command/Size.dhall
let triggerCommand = ./Pipeline/TriggerCommand.dhall

let jobs : List JobSpec.Type =
  List/map
    Pipeline.CompoundType
    JobSpec.Type
    (\(composite: Pipeline.CompoundType) -> composite.spec)
    ./gen/Jobs.dhall

-- Run a job if we touched a dirty path
let makeCommand : JobSpec.Type -> Cmd.Type = \(job : JobSpec.Type) ->
  let dirtyWhen = SelectFiles.compile job.dirtyWhen
  let trigger = triggerCommand "src/Jobs/${job.path}/${job.name}.dhall"
  in Cmd.quietly ''
    if cat _computed_diff.txt | egrep -q '${dirtyWhen}'; then
        echo "Triggering ${job.name} for reason:"
        cat _computed_diff.txt | egrep '${dirtyWhen}'
        ${Cmd.format trigger}
    fi
  ''

let prefixCommands = [
  Cmd.run "git config http.sslVerify false", -- make git work inside container
  Cmd.run "git fetch origin", -- Freshen the cache
  Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
]

let commands = Prelude.List.map JobSpec.Type Cmd.Type makeCommand jobs

in Pipeline.build Pipeline.Config::{
  spec = JobSpec::{
    name = "monorepo-triage",
    -- TODO: Clean up this code so we don't need an unused dirtyWhen here
    dirtyWhen = [ SelectFiles.everything ]
  },
  steps = [
  Command.build
    Command.Config::{
      commands = prefixCommands # commands,
      label = "Monorepo triage",
      key = "cmds",
      target = Size.Small,
      docker = Some Docker::{ image = (./Constants/ContainerImages.dhall).toolchainBase }
    }
  ]
}

