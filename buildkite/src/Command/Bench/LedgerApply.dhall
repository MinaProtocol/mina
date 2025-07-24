let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Scope = ../../Pipeline/Scope.dhall

let Spec =
      { Type =
          { key : Text, name : Text, label : Text, scope : List Scope.Type }
      , default.scope = Scope.Full
      }

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{ build_flag = BuildFlags.Type.Instrumented }

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  BenchBase.pipeline
            BenchBase.Spec::{
            , path = "Bench"
            , name = spec.name
            , label = spec.label
            , key = spec.key
            , bench = "ledger-apply"
            , scope = spec.scope
            , dependsOn = dependsOn
            , additionalDirtyWhen =
              [ SelectFiles.exactly
                  "buildkite/src/Command/Bench/LedgerApply"
                  "dhall"
              , SelectFiles.exactly
                  "buildkite/scripts/tests/ledger_test_apply"
                  "sh"
              , SelectFiles.exactly "scripts/tests/ledger_test_apply" "sh"
              ]
            , preCommands =
                RunInToolchain.runInToolchain
                  [ "DUNE_INSTRUMENT_WITH=bisect_ppx"
                  , "COVERALLS_TOKEN"
                  , "BENCHMARK_FILE=input.json"
                  ]
                  "buildkite/scripts/tests/ledger_test_apply.sh && buildkite/scripts/upload-partial-coverage-data.sh ${spec.key}"
            }

in  { pipeline = pipeline, Spec = Spec }
