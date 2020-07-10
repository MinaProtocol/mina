let Cmd = ../Lib/Cmds.dhall

let S = ../Lib/SelectFiles.dhall

let JobSpec = ../Pipeline/JobSpec.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let Command = ../Command/Base.dhall
let Docker = ../Command/Docker/Type.dhall
let Size = ../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [ S.contains "transition" ],
      name = "Sample"
    },
    steps = [
    Command.build
      Command.Config::{
        commands = [ Cmd.run "echo \"hello\"" ],
        label = "Test Echo", key = "hello",
        target = Size.Small,
        docker = Some Docker::{ image = (../Constants/ContainerImages.dhall).toolchainBase }
      }
    ]
  }
