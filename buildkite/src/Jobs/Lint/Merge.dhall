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
            , label = "Merge: compatible"
            , key = "clean-merge-compatible"
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/merges-cleanly.sh develop" ]
            , label = "Merge: develop"
            , key = "clean-merge-develop"
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/merges-cleanly.sh master" ]
            , label = "Merge: master"
            , key = "clean-merge-master"
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "scripts/merged-to-proof-systems.sh compatible" ]
            , label =
                "[proof-systems] Merge: compatible"
            , key = "merged-to-proof-systems-compatible"
            , soft_fail = Some (B/SoftFail.Boolean True)
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "scripts/merged-to-proof-systems.sh berkeley" ]
            , label =
                "[proof-systems] Merge: berkeley"
            , key = "merged-to-proof-systems-berkeley"
            , soft_fail = Some (B/SoftFail.Boolean True)
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "scripts/merged-to-proof-systems.sh develop" ]
            , label =
                "[proof-systems] Merge: develop"
            , key = "merged-to-proof-systems-develop"
            , soft_fail = Some (B/SoftFail.Boolean True)
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "scripts/merged-to-proof-systems.sh master" ]
            , label =
                "[proof-systems] Merge: master"
            , key = "merged-to-proof-systems-master"
            , soft_fail = Some (B/SoftFail.Boolean True)
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "true" ] : List Cmd.Type
            , label = "pr"
            , key = "pr"
            , target = Size.Small
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        ]
      }
