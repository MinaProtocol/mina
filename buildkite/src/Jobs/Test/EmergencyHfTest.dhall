let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let key = "emergency-hf-test"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/archive_hardfork_toolbox")
          , S.strictlyStart (S.contains "src/app/archive")
          ]
        , path = "Test"
        , name = "EmergencyHfTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ RunWithPostgres.runInDockerWithPostgresConn
                  ([] : List Text)
                  (None RunWithPostgres.ScriptOrArchive)
                  ContainerImages.minaToolchain
                  "./scripts/tests/archive-hardfork-toolbox/test-convert-canonical-blocks.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key} "
              ]
            , label = "Emergency HF test"
            , key = "emergency-hf-test"
            , target = Size.Large
            }
        ]
      }
