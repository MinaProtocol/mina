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
-- The channel and the repositories are read from the environment, via
-- DebianChannel.effective and DebianRepo.effective, so the release pipelines
-- share this one job and differ only in what they set. One step per
-- repository: a release that goes to packages.o1test.net and to the signed
-- stable repository is two publishes of the same files, and a failure in one
-- must not hide the other. Unset, MINA_RELEASE_DEBIAN_REPOS means
-- packages.o1test.net alone, which is what every release did before the
-- variable existed.

let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let PublishDebians = ../../Command/Packages/PublishDebians.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let repos = DebianRepo.effective [ DebianRepo.Type.O1Test ]

let step =
          \(repo : DebianRepo.Type)
      ->  let name = DebianRepo.lowerName repo

          in  PublishDebians.step
                PublishDebians.Spec::{
                , codenames =
                  [ DebianVersions.DebVersion.Bookworm
                  , DebianVersions.DebVersion.Jammy
                  , DebianVersions.DebVersion.Noble
                  ]
                , debianRepo = repo
                , label = "Publish: debians to ${name}"
                , key = "publish-debians-${name}"
                }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "PublishDebians"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.Publish, PipelineTag.Type.Release ]
        }
      , steps = List/map DebianRepo.Type Command.Type step repos
      }
