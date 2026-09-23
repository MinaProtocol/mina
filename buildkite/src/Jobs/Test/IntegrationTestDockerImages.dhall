-- Builds the daemon and archive docker images the integration tests run
-- against, and saves them (zstd) into the shared Hetzner CI cache
-- (/var/storagebox/docker-cache) via scripts/docker/build.sh --save-to-ci-cache.
-- The integration-test jobs load them from that cache
-- (buildkite/scripts/docker/load_from_cache.sh) instead of pulling from GAR.
--
-- The images are built --load-only and never pushed, so the integration tests
-- no longer wait on a registry push and no longer fail when GAR does. They
-- install the .deb the debian build already put in the local repo, so nothing
-- is recompiled here.
--
-- The daemon image is DaemonAppsOnly (generic), not Daemon: the swarm the
-- integration tests deploy runs mina-daemon:<tag>-devnet-generic, which is what
-- that artifact produces.
--
-- Step keys come from DockerImage.stepKey, so the integration tests'
-- depends_on (daemon_apps_only-docker-image / archive-docker-image) resolve
-- against this
-- job instead of the published MinaArtifact one.

let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let DockerImage = ../../Command/DockerImage.dhall

let MinaArtifact = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let DockerPublish = ../../Constants/DockerPublish.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let Size = ../../Command/Size.dhall

let debDeps = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}

let artifactDefaults = MinaArtifact.MinaBuildSpec.default

let daemonSpec =
      DockerImage.ReleaseSpec::{
      , deps = debDeps
      , service = Artifacts.Type.DaemonAppsOnly
      , generic = True
      , network = Network.Type.Devnet
      , deb_codename = DebianVersions.DebVersion.Bookworm
      , deb_profile = Profiles.Type.Devnet
      , deb_repo = DebianRepo.Type.Local
      , deb_legacy_version = artifactDefaults.deb_legacy_version
      , deb_storage_repair_version = Some
          artifactDefaults.deb_storage_repair_version
      , docker_publish = DockerPublish.Type.Disabled
      , save_to_ci_cache = True
      , size = Size.XLarge
      }

let archiveSpec =
      DockerImage.ReleaseSpec::{
      , deps = debDeps
      , service = Artifacts.Type.Archive
      , network = Network.Type.Devnet
      , deb_codename = DebianVersions.DebVersion.Bookworm
      , deb_profile = Profiles.Type.Devnet
      , deb_repo = DebianRepo.Type.Local
      , deb_legacy_version = artifactDefaults.deb_legacy_version
      , deb_storage_repair_version = Some
          artifactDefaults.deb_storage_repair_version
      , docker_publish = DockerPublish.Type.Disabled
      , save_to_ci_cache = True
      , size = Size.XLarge
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
          , S.strictlyStart (S.contains "scripts/docker")
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
      , steps =
        [ DockerImage.generateStep daemonSpec
        , DockerImage.generateStep archiveSpec
        ]
      }
