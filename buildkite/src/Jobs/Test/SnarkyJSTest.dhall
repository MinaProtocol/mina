let S = ../../Lib/SelectFiles.dhall
let B = ../../External/Buildkite.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let key = "snarkyjs-bindings-test"
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
        name = "SnarkyJSTest",
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
      },
    steps = [
      Command.build
        Command.Config::{
            commands = RunInToolchain.runInToolchainBuster ["DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN"] "buildkite/scripts/test-snarkyjs-bindings.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key} dev"
          , label = "SnarkyJS unit tests"
          , key = key
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
