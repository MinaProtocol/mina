-- Push the docker images this release built, beside PublishDebians.
--
-- Packaging writes every image to the build cache and pushes nothing, so this
-- is where images reach a registry: in the publish stage, after the same gate
-- as the debians. Nightly and PR builds run packaging but select no publish
-- stage, so they cannot push.
--
-- Scope, tags and dirtyWhen as PublishDebians. The registry is in the image
-- tags, set at packaging time from MINA_RELEASE_DOCKER_REPO; the first step
-- pushes them as they are. MINA_RELEASE_DOCKER_MIRROR adds a second step that
-- retags the images for that registry and pushes the copy, narrowed by
-- MINA_RELEASE_DOCKER_MIRROR_TAGS, so a release can go to docker.io in full
-- and keep one codename on the internal registry. The two steps are
-- independent, as the two debian publishes are: a failure in one must not
-- hide the other.
--
-- Each step logs in to docker.io itself, as the image steps do. Without it
-- the push runs with whatever credentials an earlier job left on the agent,
-- so the same build passes on one agent and is denied on another.

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let DockerLogin = ../../Command/DockerLogin/Type.dhall

let Size = ../../Command/Size.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let publish =
          \(label : Text)
      ->  \(key : Text)
      ->  \(command : Text)
      ->  Command.build
            Command.Config::{
            , commands = [ Cmd.run command ]
            , docker_login = Some DockerLogin::{=}
            , label = label
            , key = key
            , target = Size.Small
            }

let primary =
      publish
        "Publish: docker images"
        "publish-dockers"
        "./buildkite/scripts/docker/publish_from_cache.sh"

let mirrorSteps =
      merge
        { Some =
                \(repo : DockerRepo.Type)
            ->  [ publish
                    "Publish: docker images to ${DockerRepo.show repo}"
                    "publish-dockers-mirror"
                    "MINA_PUBLISH_TARGET_REGISTRY=${DockerRepo.show
                                                      repo} ./buildkite/scripts/docker/publish_from_cache.sh"
                ]
        , None = [] : List Command.Type
        }
        DockerRepo.mirror

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "PublishDockers"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.Publish, PipelineTag.Type.Release ]
        }
      , steps = [ primary ] # mirrorSteps
      }
