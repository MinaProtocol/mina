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
          [ S.contains "buildkite/src", S.exactly "buildkite/Makefile" "" ]
        , path = "Lint"
        , name = "Dhall"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Lint
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make check_syntax" ]
            , label = "Dhall: syntax"
            , key = "check-dhall-syntax"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make check_lint" ]
            , label = "Dhall: lint"
            , key = "check-dhall-lint"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make check_format" ]
            , label = "Dhall: format"
            , key = "check-dhall-format"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        ]
      }
