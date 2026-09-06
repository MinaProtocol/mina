let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let DockerLogin = ../../Command/DockerLogin/Type.dhall

let Cmd = ../../Lib/Cmds.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "buildkite/scripts/docker/verify-toolchain-cache" "sh"
          , S.exactly
              "buildkite/src/Jobs/Test/MinaToolchainCacheValidation"
              "dhall"
          ]
        , path = "Test"
        , name = "MinaToolchainCacheValidation"
        , scope = [ PipelineScope.Type.MainlineNightly ]
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Toolchain
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "./buildkite/scripts/docker/verify-toolchain-cache.sh" ]
            , label = "Verify mina-toolchain Hetzner cache matches docker.io"
            , key = "verify-toolchain-cache"
            , target = Size.Large
            , docker_login = Some DockerLogin::{=}
            }
        ]
      }
