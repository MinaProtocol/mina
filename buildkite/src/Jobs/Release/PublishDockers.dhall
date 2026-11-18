-- Push the docker images this release built, beside PublishDebians.
--
-- Packaging writes every image to the build cache and pushes nothing, so this
-- is where images reach a registry: in the publish stage, after the same gate
-- as the debians. Nightly and PR builds run packaging but select no publish
-- stage, so they cannot push.
--
-- Scope, tags and dirtyWhen as PublishDebians. One step per registry, and the
-- registry is decided here, by this pipeline's environment, as the debian
-- repositories are: MINA_RELEASE_DOCKER_REPO names the first target (the
-- internal euro registry unless it says otherwise, the same default as
-- packaging) and MINA_RELEASE_DOCKER_MIRROR a second one, narrowed by
-- MINA_RELEASE_DOCKER_MIRROR_TAGS, so a release can go to docker.io in full
-- and keep one codename on the internal registry. Each step retags the cached
-- images for its registry when they were tagged for another one. Packaging
-- reads MINA_RELEASE_DOCKER_REPO too, for the tags it writes into the cache;
-- the two pipelines should agree, but when they do not, this one wins and the
-- step says so in its log. The public registry gets no hash tag
-- (DockerRepo.hashTag), whatever the archive holds.
--
-- The two steps are independent, as the two debian publishes are: a failure
-- in one must not hide the other.
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

let target =
    -- The publish script's inputs for one registry.
          \(repo : DockerRepo.Type)
      ->      "MINA_PUBLISH_TARGET_REGISTRY=${DockerRepo.show repo}"
          ++  " MINA_PUBLISH_HASH_TAG=${      if DockerRepo.hashTag repo

                                        then  "1"

                                        else  "0"}"

let primaryRepo = DockerRepo.effective DockerRepo.Type.InternalEurope

let primary =
      publish
        "Publish: docker images to ${DockerRepo.show primaryRepo}"
        "publish-dockers"
        "${target primaryRepo} ./buildkite/scripts/docker/publish_from_cache.sh"

let mirrorSteps =
      merge
        { Some =
                \(repo : DockerRepo.Type)
            ->  [ publish
                    "Publish: docker images to ${DockerRepo.show repo}"
                    "publish-dockers-mirror"
                    "${target
                         repo} MINA_PUBLISH_MIRROR=1 ./buildkite/scripts/docker/publish_from_cache.sh"
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
