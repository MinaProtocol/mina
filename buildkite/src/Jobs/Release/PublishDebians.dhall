-- Publish this build's .deb files to the channel the pipeline named.
--
-- Scoped to Release and tagged Publish so it is selected only by a release
-- pipeline's publish stage. Nothing else runs it: nightly builds packages and
-- deliberately does not publish them.
--
-- dirtyWhen is `everything` because this is not a reaction to a file changing.
-- It is what the pipeline exists to do, and the scope keeps it out of every
-- other pipeline.
--
-- The channel and the repository are read from the environment via
-- DebianChannel.effective, so the three release pipelines share this one job
-- and differ only in what they set.

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PublishDebians = ../../Command/Packages/PublishDebians.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "PublishDebians"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.Publish, PipelineTag.Type.Release ]
        }
      , steps =
        [ PublishDebians.step
            PublishDebians.Spec::{
            , codenames = [ DebianVersions.DebVersion.Bullseye ]
            , debianRepo = DebianRepo.Type.Unstable
            , label = "Publish: debians"
            , key = "publish-debians"
            }
        ]
      }
