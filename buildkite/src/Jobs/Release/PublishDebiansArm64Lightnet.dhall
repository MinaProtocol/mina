-- Publish the Bookworm arm64 packages that the o1-labs/mina-lightnet-docker
-- release images install: mina-devnet-generic, mina-archive-devnet and
-- mina-logproc, with their mina dependencies. Both images of a release use
-- them: <version>-lightnet (no proofs, lightnet profile selected at runtime)
-- and <version>-devnet (full proofs, devnet profile).
--
-- A release builds arm64 apps but its packaging stages select amd64 only
-- (PackagingAmd64*), so the stable repository has no arm64 Mina packages and
-- the mina-lightnet-docker release images are amd64 only. A separate release
-- pipeline packages arm64 (filter PackagingArm64Lightnet) and runs this job
-- (filter PublishArm64Lightnet) in its publish stage.
--
-- Same command as PublishDebians, with three differences:
--
-- * Bookworm only. Arm64 is packaged for Bookworm only, and the
--   mina-lightnet-docker images are based on Bookworm. With other codenames
--   the folder would have no arm64 root package and the selection would fail.
-- * The roots are named (releasePackages), so a package that was not built
--   fails the selection instead of a part of the set going out.
-- * Tagged PublishArm64, not Publish. The amd64 publish pipelines select
--   Publish in Any mode and would run this job too.
--   No Arm64 or Lightnet tag either: filters such as DockerBuildArm64 or
--   AllDockersAndDebians select in Any mode and would pick it up.
--
-- The debians are read from this build (ROOT is the build id), so the
-- packaging and the publish stage belong in one build, and the build must not
-- set MINA_GENERIC_CACHE_ROOT: that names the amd64 generic packages, which
-- have the same names and versions as the arm64 ones.
--
-- The repositories and the channel come from the environment, as for
-- PublishDebians (MINA_RELEASE_DEBIAN_REPO, MINA_RELEASE_DEBIAN_MIRROR,
-- MINA_RELEASE_CHANNEL). Do not run it while an amd64 publish to the same
-- repository runs: both take the deb-s3 lock of dists/bookworm/<channel>.

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

let repos = DebianRepo.targets DebianRepo.Type.O1Test

let step =
          \(repo : DebianRepo.Type)
      ->  let name = DebianRepo.lowerName repo

          in  PublishDebians.step
                PublishDebians.Spec::{
                , codenames = [ DebianVersions.DebVersion.Bookworm ]
                , debianRepo = repo
                , releasePackages = Some
                    "mina-devnet-generic,mina-archive-devnet,mina-logproc"
                , label = "Publish: arm64 lightnet debians to ${name}"
                , key = "publish-debians-arm64-lightnet-${name}"
                }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "PublishDebiansArm64Lightnet"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.PublishArm64, PipelineTag.Type.Release ]
        }
      , steps = List/map DebianRepo.Type Command.Type step repos
      }
