let Pipeline = ../../Lib/Pipeline.dhall
let Command = ../../Lib/Command.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command.Config::{ command = [ "echo \"hello2\"" ], label = "Test Echo2", key = "hello2", target = <Large | Small>.Small }
    ]
  }
