let SimpleUnitTestJob = ../../Lib/SimpleUnitTestJob.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Size = ../../Command/Size.dhall

in  SimpleUnitTestJob.build
      { name = "MinaHealthcheckUnitTest"
      , keyPrefix = "mina-healthcheck"
      , label = "Mina healthcheck unit tests"
      , testProfile = "dev"
      , testPath = "src/app/mina_healthcheck"
      , tags =
        [ PipelineTag.Type.Fast
        , PipelineTag.Type.Test
        , PipelineTag.Type.Stable
        ]
      , cmdTarget = Size.Small
      , submodules = False
      }
