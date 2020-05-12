let Pipeline = ../../Lib/Pipeline.dhall
let Command = ../../Lib/Command.dhall
let Docker = ../../Lib/Docker.dhall
let Size = ../../Lib/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command.Config::{
        command = [ "echo \"hello2\"" ],
        label = "Test Echo2", key = "hello2",
        target = Size.Small,
        docker = Docker.Config::{ image = (../../Constants/ContainerImages.dhall).toolchainBase }
        }
    ]
  }
