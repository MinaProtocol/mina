let Pipeline = ../../Lib/Pipeline.dhall
let Command = ../../Lib/Command.dhall
let Docker = ../../Lib/Docker.dhall
let Size = ../../Lib/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command.Config::{ command = [ "cd .buildkite && make check" ], label = "Check all CI Dhall entrypoints", key = "check", target = Size.Small,
      docker = Docker.Config::{ image = "localhost:8080/bash/git/buildkite-agent/coreutils/dhall/gnumake" }
      }
    ]
  }
