let S = ../Lib/SelectFiles.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ../Command/Base.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let Docker = ../Command/Docker/Type.dhall

let Size = ../Command/Size.dhall

let Profiles = ../Constants/Profiles.dhall

let Spec =
      { Type =
          { profile : Profiles.Type
          , test_app_path : Text
          , timeout : Natural
          , individual_test_timeout : Natural
          , cmd_target : Size
          , job_path : Text
          , job_name : Text
          , tags : List PipelineTag.Type
          , mode : PipelineMode.Type
          , additional_dirty_when : List S.Type
          }
      , default =
          { profile = Profiles.Type.Dev
          , test_app_path =
              "src/lib/transaction_snark/test/zkapp_fuzzy/zkapp_fuzzy.exe"
          , timeout = 1200
          , individual_test_timeout = 300
          , cmd_target = Size.Small
          , additional_dirty_when = [] : List S.Type
          }
      }

let buildTestCmd
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  let timeout = Natural/show spec.timeout

          let individual_test_timeout =
                Natural/show spec.individual_test_timeout

          let key = "fuzzy-zkapp-unit-test-${Profiles.duneProfile spec.profile}"

          in  Command.build
                Command.Config::{
                , commands =
                    RunInToolchain.runInToolchain
                      [ "DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN" ]
                      "buildkite/scripts/fuzzy-zkapp-test.sh ${Profiles.duneProfile
                                                                 spec.profile} ${spec.test_app_path} ${timeout} ${individual_test_timeout} && buildkite/scripts/upload-partial-coverage-data.sh ${key} dev"
                , label = "Fuzzy zkapp unit tests"
                , key = key
                , target = spec.cmd_target
                , docker = None Docker.Type
                , artifact_paths = [ S.contains "core_dumps/*" ]
                , flake_retry_limit = Some 0
                }

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  Pipeline.Config::{
          , spec =
              let unitDirtyWhen =
                      [ S.strictlyStart (S.contains "src/lib")
                      , S.strictlyStart
                          ( S.contains
                              "src/lib/transaction_snark/test/zkapp_fuzzy"
                          )
                      , S.exactly "buildkite/src/Command/FuzzyZkappTest" "dhall"
                      , S.exactly "buildkite/scripts/fuzzy-zkapp-test" "sh"
                      ]
                    # spec.additional_dirty_when

              in  JobSpec::{
                  , dirtyWhen = unitDirtyWhen
                  , path = spec.job_path
                  , name = spec.job_name
                  , tags = spec.tags
                  , mode = spec.mode
                  }
          , steps = [ buildTestCmd spec ]
          }

in  { pipeline = pipeline, Spec = Spec }
