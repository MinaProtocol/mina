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

let buildTestCmd : Text -> Text -> Size -> Command.Type = \(profile : Text) -> \(cmd_target : Size) ->
  let command_key = "zkapps-examples-unit-test-${profile}"
  in
  Command.build
    Command.Config::{
      commands = RunInToolchain.runInToolchain ["DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN"] "buildkite/scripts/zkapps-examples-unit-tests.sh ${profile} ${path} && buildkite/scripts/upload-partial-coverage-data.sh ${command_key} dev",
      label = "${profile} zkApps examples tests",
      key = command_key,
      target = cmd_target,
      docker = None Docker.Type,
      artifact_paths = [ S.contains "core_dumps/*" ]
    }

in

Pipeline.build
  Pipeline.Config::{
    spec =
      let unitDirtyWhen = [
        S.strictlyStart (S.contains "src/app/zkapps_examples"),
        S.strictlyStart (S.contains "src/lib"),
        S.exactly "buildkite/src/Jobs/Test/DaemonUnitTest" "dhall",
        S.exactly "scripts/link-coredumps" "sh",
        S.exactly "buildkite/scripts/zkapps-examples-unit-tests" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = unitDirtyWhen,
        path = "Test",
        name = "ZkappsExamplesUnitTest"
      },
    steps = [
      buildTestCmd "dev" Size.XLarge
    ]
  }
