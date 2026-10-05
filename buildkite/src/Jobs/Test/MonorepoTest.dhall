let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "buildkite/scripts/monorepo" "sh"
          , S.exactly "buildkite/scripts/monorepo_lib" "sh"
          , S.exactly "buildkite/scripts/test_monorepo" "sh"
          ]
        , path = "Test"
        , name = "MonorepoTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make test_monorepo" ]
            , label = "Monorepo: tests"
            , key = "check-monorepo-tests"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        ]
      }
