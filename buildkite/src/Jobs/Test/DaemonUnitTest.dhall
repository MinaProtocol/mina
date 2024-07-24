let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Cmd = ../../Lib/Cmds.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let buildTestCmd
    : Text -> Text -> Size -> Command.Type
    =     \(profile : Text)
      ->  \(path : Text)
      ->  \(cmd_target : Size)
      ->  let command_key = "unit-test-${profile}"
          let lagrange_cache_dir = "/tmp/lagrange-cache"
          let lagrange_cache_bucket = "o1labs-ci-test-data"

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      "buildkite/scripts/lagrange-cache-manager.sh create_cache_dir ${lagrange_cache_dir}"
                  , Cmd.run
                      "buildkite/scripts/lagrange-cache-manager.sh restore_cache ${lagrange_cache_bucket} ${lagrange_cache_dir}"
                  ]
                  # RunInToolchain.runInToolchain
                      [ "DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN", "LAGRANGE_CACHE_DIR=${lagrange_cache_dir}" ]
                      "buildkite/scripts/unit-test.sh ${profile} ${path} && buildkite/scripts/upload-partial-coverage-data.sh ${command_key} dev"
                  # [ Cmd.run
                      "buildkite/scripts/lagrange-cache-manager.sh upload_cache_if_changed ${lagrange_cache_bucket} ${lagrange_cache_dir}"
                    ]
                , label = "${profile} unit-tests"
                , key = command_key
                , target = cmd_target
                , docker = None Docker.Type
                , artifact_paths = [ S.contains "core_dumps/*" ]
                }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let unitDirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.strictly (S.contains "Makefile")
                , S.exactly "buildkite/src/Jobs/Test/DaemonUnitTest" "dhall"
                , S.exactly "buildkite/src/Constants/ContainerImages" "dhall"
                , S.exactly "scripts/link-coredumps" "sh"
                , S.exactly "buildkite/scripts/unit-test" "sh"
                ]

          in  JobSpec::{
              , dirtyWhen = unitDirtyWhen
              , path = "Test"
              , name = "DaemonUnitTest"
              , tags = [ PipelineTag.Type.VeryLong, PipelineTag.Type.Test ]
              }
      , steps = [ buildTestCmd "dev" "src/lib" Size.XLarge ]
      }
