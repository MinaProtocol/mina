let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Test"
        , name = "PatchesApply"
        , mode = PipelineMode.Type.Stable
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.nixos
                  , privileged = True
                  }
                  "both(){git apply \$1 && git apply -R \$1}; both scripts/hardfork/localnet-patches/berkeley.patch && both buildkite/scripts/caqti-upgrade.patch && both buildkite/scripts/caqti-upgrade-plus-archive-init-speedup.patch"
              ]
            , label = "check that patches still apply"
            , key = "patches-apply"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
