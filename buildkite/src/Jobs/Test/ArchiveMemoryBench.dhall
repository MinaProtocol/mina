let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let RunPerformanceTest = ../../Command/RunPerformanceTest.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let FixPermissions = ../../Command/FixPermissions.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/lib/mina_caqti")
          , S.strictlyStart (S.contains "src/app/archive_blocks")
          , S.strictlyStart (S.contains "src/test/archive/sample_zkapp_heavy")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/ArchiveMemoryBench")
          , S.exactly "buildkite/scripts/tests/archive-memory-bench" "py"
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
              [ FixPermissions.command Arch.Type.Amd64
              , RunWithPostgres.runInDockerWithPostgresConn
                  [ "BUILDKITE_BRANCH", "BUILDKITE_COMMIT" ]
                  ( Some
                      ( RunWithPostgres.ScriptOrArchive.Script
                          "src/app/archive/create_schema.sql"
                      )
                  )
                  ContainerImages.minaToolchain
                  "-c 'python3 ./buildkite/scripts/tests/archive-memory-bench.py'"
              ]
            }
        ]
      }
