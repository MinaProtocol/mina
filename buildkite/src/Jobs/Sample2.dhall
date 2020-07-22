let Cmd = ../Lib/Cmds.dhall

let S = ../Lib/SelectFiles.dhall

let JobSpec = ../Pipeline/JobSpec.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let Command = ../Command/Base.dhall
let Docker = ../Command/Docker/Type.dhall
let Size = ../Command/Size.dhall

let c1 = Command.Config::{
        commands = [ Cmd.run "echo \"hello2\"" ],
        label = "Test Echo2", key = "hello2",
        target = Size.Small,
        docker = Some Docker::{ image = (../Constants/ContainerImages.dhall).toolchainBase }
        }

let name = "Sample2"

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [
        S.contains "src/lib",
        S.contains "buildkite"
      ],
      name = name
    },
    steps = [
    Command.build c1,
    Command.build
      Command.Config::{
        commands = [ Cmd.run "echo \"hello again\"" ],
        label = "Test Echo2", key = "hello-again",
        target = Size.Small,
        docker = Some Docker::{ image = (../Constants/ContainerImages.dhall).toolchainBase },
        depends_on = [ { name = name, key = c1.key } ]
        }
    ]
  }
