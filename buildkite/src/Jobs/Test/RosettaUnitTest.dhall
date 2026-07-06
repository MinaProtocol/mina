let SimpleUnitTestJob = ../../Lib/SimpleUnitTestJob.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Size = ../../Command/Size.dhall

in  SimpleUnitTestJob.build
      { name = "RosettaUnitTest"
      , keyPrefix = "rosetta"
      , label = "Rosetta unit tests"
      , testProfile = "dev"
      , testPath = "src/app/rosetta"
      , tags =
        [ PipelineTag.Type.Long
        , PipelineTag.Type.Test
        , PipelineTag.Type.Stable
        , PipelineTag.Type.Rosetta
        ]
      , cmdTarget = Size.Small
      }
