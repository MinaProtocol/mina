let B = ../../External/Buildkite.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ SelectFiles.everything ]
        , path = "Lint"
        , name = "Merge"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/merges-cleanly.sh compatible" ]
            , label = "Check merges cleanly into compatible"
            , key = "clean-merge-compatible"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/merges-cleanly.sh develop" ]
            , label = "Check merges cleanly into develop"
            , key = "clean-merge-develop"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/merges-cleanly.sh master" ]
            , label = "Check merges cleanly into master"
            , key = "clean-merge-master"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "scripts/merged-to-proof-systems.sh master" ]
            , label =
                "[proof-systems] Check merges cleanly into proof-systems master branch"
            , key = "merged-to-proof-systems-master"
            , soft_fail = Some (B/SoftFail.Boolean False)
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "scripts/merged-to-kimchi-stubs-vendors.sh main" ]
            , label =
                "[kimchi-stubs-vendors] Check merges cleanly into kimchi-stubs-vendors main branch"
            , key = "merged-to-kimchi-stubs-vendors-main"
            , soft_fail = Some (B/SoftFail.Boolean False)
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "true" ] : List Cmd.Type
            , label = "pr"
            , key = "pr"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        ]
      }
