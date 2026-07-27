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
        [ RunPerformanceTest.command
            RunPerformanceTest.Spec::{
            , key = "mina-caqti-pg-memory-bench"
            , label = "Mina caqti postgres memory-usage bench"
            , runCommands =
              [ RunWithPostgres.runInDockerWithPostgresConn
                  [ "BUILDKITE_BRANCH", "BUILDKITE_COMMIT" ]
                  (None RunWithPostgres.ScriptOrArchive)
                  ContainerImages.minaToolchain
                  ( WithCargo.withCargo
                      "./buildkite/scripts/tests/mina-caqti-pg-memory-bench.sh"
                  )
              ]
            }
        ]
      }
