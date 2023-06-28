let S = ../../Lib/SelectFiles.dhall
let B = ../../External/Buildkite.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Test/SnarkyJSTest"),
          S.strictlyStart (S.contains "buildkite/scripts/test-snarkyjs-bindings.sh"),
          S.strictlyStart (S.contains "src/lib")
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
          , soft_fail = Some (B/SoftFail.Boolean True)
        },
      Command.build
        Command.Config::{
            commands = RunInToolchain.runInToolchainBuster ([] : List Text) "buildkite/scripts/test-snarkyjs-bindings-minimal.sh"
          , label = "SnarkyJS minimal tests"
          , key = "snarkyjs-minimal-test"
          , target = Size.XLarge
          , docker = None Docker.Type
        }
    ]
  }
