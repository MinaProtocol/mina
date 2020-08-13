-- BENCHMARKING

let Prelude = ../External/Prelude.dhall
let S = ../Lib/SelectFiles.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall
let Command = ../Command/Base.dhall
let OpamInit = ../Command/OpamInit.dhall
let Docker = ../Command/Docker/Type.dhall
let Size = ../Command/Size.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = 
      JobSpec::{
        dirtyWhen = OpamInit.dirtyWhen # [
          S.strictlyStart (S.contains "buildkite/src/Jobs/ClientSdk"),
          S.strictlyStart (S.contains "src")
        ],
        name = "ClientSdk"
      },
    steps = [
    Command.build
      Command.Config::{
        commands = OpamInit.andThenRunInDocker ([] : List Text) "./buildkite/scripts/build-client-sdk.sh",
        label = "Build client-sdk",
        key = "build-client-sdk",
        target = Size.Medium,
        docker = None Docker.Type
      }
    ]
  }

