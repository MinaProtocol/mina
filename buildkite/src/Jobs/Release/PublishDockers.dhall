-- Push the docker images this build cached.
--
-- The packaging stage builds every image and writes it to the CI cache without
-- pushing, so this is where images reach a registry -- in the same stage the
-- debians do, after the same gate.
--
-- Nightly runs the packaging jobs but not this one, which is what stops
-- nightly pushing. Nothing is conditional: a pipeline either selects the
-- Publish stage or it does not.

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

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
            , label = "Publish: docker images"
            , key = "publish-dockers"
            , target = Size.Small
            }
        ]
      }
