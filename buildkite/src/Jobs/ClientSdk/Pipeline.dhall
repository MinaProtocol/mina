let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Coda = ../../Command/Coda.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = OpamInit.andThenRunInDocker
            "mkdir -p /tmp/artifacts && ./buildkite/scripts/build-client-sdk.sh",
        label = "Build client-sdk",
        key = "build-client-sdk",
        target = Size.Large,
        docker = None Docker.Type
      }
    ]
  }

