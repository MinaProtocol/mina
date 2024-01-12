let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall


let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let buildTestCmd : Text -> Text -> Size -> Command.Type = \(profile : Text) -> \(path : Text) -> \(cmd_target : Size) ->
  let key = "single-node-tests-${profile}" in
  Command.build
    Command.Config::{
      commands = RunInToolchain.runInToolchain ["DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN"] "buildkite/scripts/single-node-tests.sh ${path} && buildkite/scripts/upload-partial-coverage-data.sh ${key} dev",
      label = "${profile} single-node-tests",
      key = key,
      target = cmd_target,
      docker = None Docker.Type
    }

in

Pipeline.build
  Pipeline.Config::{
    spec = 
      let unitDirtyWhen = [
        S.strictlyStart (S.contains "src/lib"),
        S.strictlyStart (S.contains "src/test"),
        S.strictly (S.contains "Makefile"),
        S.exactly "buildkite/src/Jobs/Test/SingleNodeTest" "dhall",
        S.exactly "buildkite/scripts/single-node-tests" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = unitDirtyWhen,
        path = "Test",
        name = "SingleNodeTest"
      },
    steps = [
      buildTestCmd "dev" "src/test/command_line_tests/command_line_tests.exe" Size.XLarge
    ]
  }