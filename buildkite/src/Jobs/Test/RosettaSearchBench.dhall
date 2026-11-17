let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let RunPerformanceTest = ../../Command/RunPerformanceTest.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let FixPermissions = ../../Command/FixPermissions.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/rosetta")
          , S.exactly "src/app/archive/create_schema" "sql"
          , S.exactly "src/app/archive/upgrade" "sql"
          , S.strictlyStart (S.contains "src/lib/mina_caqti")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/RosettaSearchBench")
          , S.exactly "buildkite/scripts/tests/rosetta-search-bench" "sh"
          ]
        , path = "Test"
        , name = "RosettaSearchBench"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Rosetta
          ]
        }
      , steps =
        [ RunPerformanceTest.command
            RunPerformanceTest.Spec::{
            , key = "rosetta-search-bench"
            , label = "Rosetta /search/transactions latency bench"
            , runCommands =
                  RunInToolchain.submodulesInit True
                # [ FixPermissions.command Arch.Type.Amd64
                  , RunWithPostgres.runInDockerWithPostgresConn
                      [ "BUILDKITE_BRANCH", "BUILDKITE_COMMIT" ]
                      ( Some
                          ( RunWithPostgres.ScriptOrArchive.Script
                              "src/app/rosetta/search_bench/init.sql"
                          )
                      )
                      ContainerImages.minaToolchain
                      "./buildkite/scripts/tests/rosetta-search-bench.sh"
                  ]
            }
        ]
      }
