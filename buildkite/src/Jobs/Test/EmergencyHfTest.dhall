let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let key = "emergency-hf-test"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/archive_hardfork_toolbox") ]
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
                  [ "CONVERT_CANONICAL_BLOCKS_TEST_APP=mina-test-convert-canonical"
                  ]
                  (None RunWithPostgres.ScriptOrArchive)
                  ( Artifacts.fullDockerTag
                      Artifacts.Tag::{
                      , artifact = Artifacts.Type.FunctionalTestSuite
                      , buildFlags = BuildFlags.Type.Instrumented
                      }
                  )
                  "./scripts/tests/archive-hardfork-toolbox/test_convert_canonical_blocks.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key} "
              ]
            , label = "Emergency HF test"
            , key = key
            , target = Size.Large
            }
        ]
      }
