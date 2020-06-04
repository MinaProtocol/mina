let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = [ "echo \"hello\"" ],
        label = "Test Echo", key = "hello",
        target = Size.Small,
        docker = Docker::{ image = (../../Constants/ContainerImages.dhall).toolchainBase }
      }
    ]
  }
