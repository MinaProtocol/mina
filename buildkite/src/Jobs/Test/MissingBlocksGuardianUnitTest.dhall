let SimpleUnitTestJob = ../../Lib/SimpleUnitTestJob.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Size = ../../Command/Size.dhall

in  SimpleUnitTestJob.build
      { name = "MissingBlocksGuardianUnitTest"
      , keyPrefix = "missing-blocks-guardian"
      , label = "Missing blocks guardian unit tests"
      , testProfile = "dev"
      , testPath = "src/app/missing_blocks_guardian"
      , tags =
        [ PipelineTag.Type.Fast
        , PipelineTag.Type.Test
        , PipelineTag.Type.Stable
        ]
      , cmdTarget = Size.Small
      , submodules = True
      }
