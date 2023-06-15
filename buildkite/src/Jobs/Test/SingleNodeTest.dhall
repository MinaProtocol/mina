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
  Command.build
    Command.Config::{
      commands = RunInToolchain.runInToolchain ([] : List Text) "buildkite/scripts/single-node-tests.sh ${path}",
      label = "${profile} single-node-tests",
      key = "single-node-tests",
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