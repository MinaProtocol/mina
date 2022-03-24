let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Test/SnarkyJSTest"),
          S.strictlyStart (S.contains "buildkite/scripts/test-snarkyjs-bindings.sh"),
          S.strictlyStart (S.contains "src")
        ],
        path = "Test",
        name = "SnarkyJSTest"
      },
    steps = [
      Command.build
        Command.Config::{
            commands = RunInToolchain.runInToolchainBuster ([] : List Text) "buildkite/scripts/test-snarkyjs-bindings.sh"
          , label = "SnarkyJS unit tests"
          , key = "snarkyjs-bindings-test"
          , target = Size.XLarge
          , docker = None Docker.Type
        }
    ]
  }
