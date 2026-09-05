-- Builds the daemon (profiled) and archive docker images the integration tests
-- run against, and saves them (zstd) into the shared Hetzner CI cache
-- (/var/storagebox/docker-cache) via scripts/docker/build.sh --save-to-ci-cache.
-- The integration-test jobs load them straight from that cache
-- (buildkite/scripts/docker/load_from_cache.sh) instead of pulling from GAR.
--
-- BOTTOM-TO-TOP. Each step builds everything it needs, starting from the
-- app-build binaries:
--
--   apps cache -> .deb files (only the packages the image installs)
--              -> docker image (--load-only, never pushed)
--              -> CI cache
--
-- It used to start one layer higher: the .deb files came from the packaging
-- job's cache (read_all_from_cache.sh) and the profiled daemon was FROM the
-- registry-published generic image, so this job depended on
-- `MinaArtifactBullseye`'s build-deb-pkg AND its daemon_apps_only docker step.
-- That dependency is a large part of why the Debian and Docker builds run at
-- all in nightly. Now the only dependency is `MinaArtifactBullseyeApps`.
--
-- The daemon step therefore builds the generic image itself before the profiled
-- one that is FROM it -- in the same step, on the same agent, so the local
-- image store satisfies the FROM without anything being pushed.
--
-- Step keys are still derived from DockerImage.stepKey, so the integration
-- tests' `depends_on` (daemon_profile-devnet-docker-image /
-- archive-devnet-docker-image) keep resolving.
--
-- Lessons learnt from #18638 (native/bare-process engine): running the daemons
-- as bare processes inside the 3 GiB CI pod OOMs (the docker engine survives
-- because its daemons run under dockerd on the host, outside the pod cgroup).
-- So we keep the docker engine and only cut the packaging dependency here.

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let S = ../../Lib/SelectFiles.dhall

let Command = ../../Command/Base.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DockerFromLocalDebs = ../../Command/DockerFromLocalDebs.dhall

let IntegrationImages = ../../Constants/IntegrationImages.dhall

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Docker = ../../Constants/Docker/Package.dhall

let BaseImage = ../../Constants/Docker/BaseImage.dhall

let Arch = ../../Constants/Arch.dhall

let Size = ../../Command/Size.dhall

let network = IntegrationImages.network

let profile = IntegrationImages.profile

let debVersion = IntegrationImages.debVersion

let arch = Arch.Type.Amd64

let baseImage = BaseImage.imageFor debVersion arch

let appsDep =
      DebianVersions.appDependsOn
        DebianVersions.DepsSpec::{
        , deb_version = debVersion
        , network = network
        , profile = profile
        , arch = arch
        }

let disableGarEnv = Some (toMap { GAR_CACHE_DISABLED = "true" })

let daemonBuildSpec =
      ArtifactPipelines.PackagingSpec::{
      , artifacts =
        [ Artifacts.Type.DaemonGeneric
        , Artifacts.Type.LogProc
        , Artifacts.Type.DaemonStorageToolbox
        , Artifacts.Type.DaemonProfiled { profile = profile }
        ]
      , debVersion = debVersion
      , arch = arch
      }

let archiveBuildSpec =
      ArtifactPipelines.PackagingSpec::{
      , artifacts =
        [ Artifacts.Type.Archive { network = network }
        , Artifacts.Type.DaemonProfiled { profile = profile }
        , Artifacts.Type.Daemon { network = network }
        ]
      , debVersion = debVersion
      , arch = arch
      }

let keySpec = IntegrationImages.keySpec

let genericImage =
      DockerFromLocalDebs.Spec::{
      , service = Docker.Type.DaemonGeneric
      , network = network
      , profile = profile
      , baseImage = Some baseImage
      }

let profiledImage =
      DockerFromLocalDebs.Spec::{
      , service = Docker.Type.DaemonProfiled { profile = profile }
      , network = network
      , profile = profile
      , saveToCiCache = True
      }

let archiveImage =
      DockerFromLocalDebs.Spec::{
      , service = Docker.Type.Archive { network = network }
      , network = network
      , profile = profile
      , baseImage = Some baseImage
      , saveToCiCache = True
      }

let daemonStep =
          Command.build
            Command.Config::{
            , commands =
                  ArtifactPipelines.buildDebianFromApps
                    daemonBuildSpec
                    "${ArtifactPipelines.debianTokens daemonBuildSpec}"
                # [ DockerFromLocalDebs.buildImages
                      debVersion
                      [ genericImage, profiledImage ]
                  ]
            , label =
                DockerImage.stepLabel (keySpec IntegrationImages.daemonService)
            , key =
                DockerImage.stepKey (keySpec IntegrationImages.daemonService)
            , target = Size.XLarge
            , depends_on = appsDep
            }
      //  { env = disableGarEnv }

let archiveStep =
      Command.build
        Command.Config::{
        , commands =
              ArtifactPipelines.buildDebianFromApps
                archiveBuildSpec
                (ArtifactPipelines.debianTokens archiveBuildSpec)
            # [ DockerFromLocalDebs.buildImages debVersion [ archiveImage ] ]
        , label =
            DockerImage.stepLabel (keySpec IntegrationImages.archiveService)
        , key = DockerImage.stepKey (keySpec IntegrationImages.archiveService)
        , target = Size.XLarge
        , depends_on = appsDep
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart (S.contains "dockerfiles")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/IntegrationTestDockerImages")
          , S.strictlyStart (S.contains "buildkite/src/Command/DockerImage")
          , S.exactly "buildkite/src/Command/DockerFromLocalDebs" "dhall"
          , S.exactly "buildkite/src/Command/MinaArtifact" "dhall"
          , S.strictlyStart (S.contains "scripts/docker")
          , S.strictlyStart (S.contains "scripts/debian")
          , S.strictlyStart (S.contains "buildkite/scripts/apps")
          , S.exactly "buildkite/src/Constants/IntegrationImages" "dhall"
          ]
        , path = "Test"
        , name = "IntegrationTestDockerImages"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , scope = PipelineScope.AllButPullRequest
        }
      , steps = [ daemonStep, archiveStep ]
      }
