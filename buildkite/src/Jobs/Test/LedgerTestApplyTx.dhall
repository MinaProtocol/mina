let PipelineTag = ../../Pipeline/Tag.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let dependsOn =
        DebianVersions.dependsOnStep
          (None Text)
          DebianVersions.DebVersion.Bullseye
          Profiles.Type.Standard
          BuildFlags.Type.Instrumented
          "build"
      # DebianVersions.dependsOnStep
          (None Text)
          DebianVersions.DebVersion.Bullseye
          Profiles.Type.Standard
          BuildFlags.Type.None
          "build"

let buildTestCmd
    : Size -> Command.Type
    =     \(cmd_target : Size)
      ->  let key = "ledger-test-apply"

          in  Command.build
                Command.Config::{
                , commands =
                    RunInToolchain.runInToolchain
                      [ "DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN" ]
                      "buildkite/scripts/tests/ledger_test_apply.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                , label = "Test: Ledger apply txs"
                , key = key
                , target = cmd_target
                , docker = None Docker.Type
                , depends_on = dependsOn
                }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let unitDirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.strictly (S.contains "Makefile")
                , S.exactly "buildkite/src/Jobs/Test/LedgerTestApplyTx" "dhall"
                , S.exactly "buildkite/scripts/tests/ledger_test_apply" "sh"
                , S.exactly "scripts/tests/ledger_test_apply" "sh"
                ]

          in  JobSpec::{
              , dirtyWhen = unitDirtyWhen
              , path = "Test"
              , name = "LedgerTestApplyTx"
              , tags =
                [ PipelineTag.Type.Long
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              }
      , steps = [ buildTestCmd Size.XLarge ]
      }
