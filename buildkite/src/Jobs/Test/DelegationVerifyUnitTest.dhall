let SimpleUnitTestJob = ../../Lib/SimpleUnitTestJob.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Size = ../../Command/Size.dhall

in  SimpleUnitTestJob.build
      { name = "DelegationVerifyUnitTest"
      , keyPrefix = "delegation-verify"
      , label = "Delegation verify unit tests"
      , testProfile = "dev"
      , testPath = "src/app/delegation_verify"
      , tags =
        [ PipelineTag.Type.Fast
        , PipelineTag.Type.Test
        , PipelineTag.Type.Stable
        ]
      , cmdTarget = Size.Small
      , submodules = True
      }
