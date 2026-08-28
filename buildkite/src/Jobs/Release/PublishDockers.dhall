-- Push the docker images this build cached, without rebuilding them.
--
-- Only wanted when the packaging stage was told to hold its images back
-- (MINA_RELEASE_DEFER_DOCKER_PUBLISH). Without that the packaging jobs push as
-- they finish and there is nothing in the cache for this job to find, so it
-- selects itself out rather than failing on an empty cache.
--
-- Tagged Publish, so a release pipeline's publish stage picks it up alongside
-- PublishDebians and the two go out together.

let S = ../../Lib/SelectFiles.dhall

let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let deferred
    : Optional Text
    = Some env:MINA_RELEASE_DEFER_DOCKER_PUBLISH as Text ? None Text

let steps
    : List Command.Type
    = Prelude.Optional.fold
        Text
        deferred
        (List Command.Type)
        (     \(_ : Text)
          ->  [ Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.run "./buildkite/scripts/docker/publish_from_cache.sh"
                    ]
                  , label = "Publish: docker images"
                  , key = "publish-dockers"
                  , target = Size.Small
                  }
              ]
        )
        ([] : List Command.Type)

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "PublishDockers"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.Publish, PipelineTag.Type.Release ]
        }
      , steps = steps
      }
