let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let WithCargo = ../../Command/WithCargo.dhall

let Benchmarks = ../../Constants/Benchmarks.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let user = "admin"

let password = "codarules"

let db = "mina_caqti_bench"

let command_key = "mina-caqti-pg-memory-bench"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/lib/mina_caqti")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/MinaCaqtiPgMemoryBench")
          , S.exactly "buildkite/scripts/tests/mina-caqti-pg-memory-bench" "sh"
          ]
        , path = "Test"
        , name = "MinaCaqtiPgMemoryBench"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                  RunInToolchain.runInToolchain
                    RunInToolchain.Config::{
                    , submodules = True
                    , environment =
                      [ "POSTGRES_PASSWORD=${password}"
                      , "POSTGRES_USER=${user}"
                      , "POSTGRES_DB=${db}"
                      , "BUILDKITE_BRANCH"
                      , "BUILDKITE_COMMIT"
                      ]
                    , innerScript =
                        WithCargo.withCargo
                          "./buildkite/scripts/tests/mina-caqti-pg-memory-bench.sh ${user} ${password} ${db}"
                    }
                # RunInToolchain.runInDefaultToolchain
                    (Benchmarks.toEnvList Benchmarks.Type::{=})
                    "./buildkite/scripts/bench/send.sh"
            , label = "Mina caqti postgres memory-usage bench"
            , key = command_key
            , target = Size.Large
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "*.perf" ]
            }
        ]
      }
