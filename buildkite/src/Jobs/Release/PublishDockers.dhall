-- Push the docker images this release built, beside PublishDebians.
--
-- Packaging writes every image to the build cache and pushes nothing, so this
-- is where images reach a registry: in the publish stage, after the same gate
-- as the debians. Nightly and PR builds run packaging but select no publish
-- stage, so they cannot push.
--
-- Scope, tags and dirtyWhen as PublishDebians. The registry is in the image
-- tags, set at packaging time from MINA_RELEASE_DOCKER_REPO; nothing is
-- retagged here.
--
-- The step logs in to docker.io itself, as the image steps do. Without it the
-- push runs with whatever credentials an earlier job left on the agent, so the
-- same build passes on one agent and is denied on another.

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let DockerLogin = ../../Command/DockerLogin/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "PublishDockers"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.Publish, PipelineTag.Type.Release ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "./buildkite/scripts/docker/publish_from_cache.sh" ]
            , docker_login = Some DockerLogin::{=}
            , label = "Publish: docker images"
            , key = "publish-dockers"
            , target = Size.Small
            }
        ]
      }
