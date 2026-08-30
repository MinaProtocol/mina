let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "buildkite/scripts/bundle-libs" "sh"
          , S.strictlyStart (S.contains "buildkite/scripts/tests")
          , S.exactly "buildkite/scripts/build-artifact" "sh"
          , S.strictlyStart (S.contains "buildkite/scripts/apps")
          , S.exactly "buildkite/src/Jobs/Test/BundleLibsTest" "dhall"
          ]
        , path = "Test"
        , name = "BundleLibsTest"
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
              [ Cmd.run "./buildkite/scripts/tests/test_bundle_libs.sh" ]
            , label = "Shared-library bundling tests"
            , key = "bundle-libs-tests"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
