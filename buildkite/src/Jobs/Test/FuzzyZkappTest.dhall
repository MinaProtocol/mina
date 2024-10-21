let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Command = ../../Command/FuzzyZkappTest.dhall

in  Pipeline.build
      ( Command.pipeline
          Command.Spec::{
          , job_path = "Test"
          , job_name = "FuzzyZkappTest"
          , tags = [ PipelineTag.Type.VeryLong, PipelineTag.Type.Test ]
          , mode = PipelineMode.Type.Stable
          , additional_dirty_when =
            [ S.exactly "buildkite/src/Jobs/Test/FuzzyZkappTest" "dhall" ]
          }
      )
      Pipeline.Config::{
      , spec =
          let unitDirtyWhen =
                [ S.strictlyStart (S.contains "src/lib")
                , S.strictlyStart
                    (S.contains "src/lib/transaction_snark/test/zkapp_fuzzy")
                , S.exactly "buildkite/src/Jobs/Test/FuzzyZkappTest" "dhall"
                , S.exactly "buildkite/scripts/fuzzy-zkapp-test" "sh"
                ]

          in  JobSpec::{
              , dirtyWhen = unitDirtyWhen
              , path = "Test"
              , name = "FuzzyZkappTest"
              , tags =
                [ PipelineTag.Type.VeryLong
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              , mode = PipelineMode.Type.Stable
              }
      , steps =
        [ buildTestCmd
            "dev"
            "src/lib/transaction_snark/test/zkapp_fuzzy/zkapp_fuzzy.exe"
            4200
            150
            Size.Small
        ]
      }
