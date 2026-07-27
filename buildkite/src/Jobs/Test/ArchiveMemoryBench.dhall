let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let RunPerformanceTest = ../../Command/RunPerformanceTest.dhall

let WithCargo = ../../Command/WithCargo.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/lib/mina_caqti")
          , S.strictlyStart (S.contains "src/app/archive_blocks")
          , S.strictlyStart (S.contains "src/test/archive/sample_zkapp_heavy")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/ArchiveMemoryBench")
          , S.exactly "buildkite/scripts/tests/archive-memory-bench" "sh"
          ]
        , path = "Test"
        , name = "ArchiveMemoryBench"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          ]
        }
      , steps =
        [ RunPerformanceTest.command
            RunPerformanceTest.Spec::{
            , key = "archive-memory-bench"
            , label = "Archive node end-to-end memory bench"
            , runCommands =
              [ RunWithPostgres.runInDockerWithPostgresConn
                  [ "BUILDKITE_BRANCH", "BUILDKITE_COMMIT" ]
                  ( Some
                      ( RunWithPostgres.ScriptOrArchive.Script
                          "src/app/archive/create_schema.sql"
                      )
                  )
                  ContainerImages.minaToolchain
                  ( WithCargo.withCargo
                      "./buildkite/scripts/tests/archive-memory-bench.sh"
                  )
              ]
            }
        ]
      }
