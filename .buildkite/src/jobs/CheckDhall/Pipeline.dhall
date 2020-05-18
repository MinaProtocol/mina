let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Dsl.dhall
let Docker = ../../Command/Docker/Dsl.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command.Config::{
        commands = [ "cd .buildkite && make check" ],
        label = "Check all CI Dhall entrypoints",
        key = "check",
        target = Size.Small,
        docker = Docker.Config::{ image = (../../Constants/ContainerImages.dhall).toolchainBase }
      }
    ]
  }
