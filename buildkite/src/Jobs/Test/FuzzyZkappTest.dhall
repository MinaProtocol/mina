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

let buildTestCmd : Text -> Text -> Natural -> Natural -> Size -> Command.Type = \(profile : Text) -> \(path : Text) -> \(timeout : Natural) -> \(individual_test_timeout : Natural) -> \(cmd_target : Size) ->
  let timeout = Natural/show timeout in
  let individual_test_timeout = Natural/show individual_test_timeout in
  Command.build
    Command.Config::{
      commands = RunInToolchain.runInToolchain ([] : List Text)
        "buildkite/scripts/fuzzy-zkapp-test.sh ${profile} ${path} ${timeout} ${individual_test_timeout}",
      label = "Fuzzy zkapp unit tests",
      key = "fuzzy-zkapp-unit-test-${profile}",
      target = cmd_target,
      docker = None Docker.Type,
      artifact_paths = [ S.contains "core_dumps/*" ],
      flake_retry_limit = Some 0
    }
in

Pipeline.build
  Pipeline.Config::{
    spec = 
      let unitDirtyWhen = [
        S.strictlyStart (S.contains "src/lib"),          
        S.strictlyStart (S.contains "src/lib/transaction_snark/test/zkapp_fuzzy"),
        S.exactly "buildkite/src/Jobs/Test/FuzzyZkappTest" "dhall",
        S.exactly "buildkite/scripts/fuzzy-zkapp-test" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = unitDirtyWhen,
        path = "Test",
        name = "FuzzyZkappTest"
      },
    steps = [
      buildTestCmd "dev" "src/lib/transaction_snark/test/zkapp_fuzzy/zkapp_fuzzy.exe" 3600 120 Size.Small
    ]
  }
