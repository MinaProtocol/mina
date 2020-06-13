let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = [
          Cmd.run "cd buildkite && make check"
        ],
        label = "Check all CI Dhall entrypoints",
        key = "check",
        target = Size.Small,
        docker = Some Docker::{ image = (../../Constants/ContainerImages.dhall).toolchainBase }
      }
    ]
  }
