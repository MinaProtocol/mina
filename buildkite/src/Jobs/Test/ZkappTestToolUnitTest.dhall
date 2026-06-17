let SimpleUnitTestJob = ../../Lib/SimpleUnitTestJob.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Size = ../../Command/Size.dhall

in  SimpleUnitTestJob.build
      { name = "ZkappTestToolUnitTest"
      , keyPrefix = "zkapp-tool"
      , label = "Zkapps test transaction tool unit tests"
      , testProfile = "dev"
      , testPath = "src/app/zkapp_test_transaction"
      , tags =
        [ PipelineTag.Type.Fast
        , PipelineTag.Type.Test
        , PipelineTag.Type.Stable
        ]
      , cmdTarget = Size.Small
      }
