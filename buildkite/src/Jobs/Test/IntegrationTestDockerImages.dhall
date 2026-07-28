-- Builds the daemon (generic) and archive docker images from the freshly-built
-- debian packages and saves them (zstd) into the shared Hetzner CI cache
-- (/var/storagebox/docker-cache) via scripts/docker/build.sh --save-to-ci-cache.
--
-- The integration-test jobs depend on this job and load those images straight
-- from the cache (buildkite/scripts/docker/load_from_cache.sh) instead of
-- pulling them from the docker registry / GAR. This decouples the integration
-- tests from the registry-push docker pipeline. The images are built load-only
-- (DockerPublish.Disabled) — they are never pushed anywhere, they only live in
-- the cache for the duration of the build.
--
-- Lessons learnt from #18638 (native/bare-process engine): running the daemons
-- as bare processes inside the 3 GiB CI pod OOMs (the docker engine survives
-- because its daemons run under dockerd on the host, outside the pod cgroup).
-- So we keep the docker engine and only cut the registry dependency here.

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let S = ../../Lib/SelectFiles.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Docker = ../../Constants/Docker/Package.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let DockerPublish = ../../Constants/Docker/Publish.dhall

let Size = ../../Command/Size.dhall

let Dockers = ../../Constants/Docker/Versions.dhall

let debDeps = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}

let genericBaseDep =
      Dockers.dependsOn
        Dockers.DepsSpec::{ artifact = Docker.Type.DaemonGeneric }

let disableGarEnv = Some (toMap { GAR_CACHE_DISABLED = "true" })

let daemonSpec =
      DockerImage.ReleaseSpec::{
      , deps = debDeps # genericBaseDep
      , service = Docker.Type.DaemonProfiled { profile = Profiles.Type.Devnet }
      , network = Network.Type.Devnet
      , deb_codename = DebianVersions.DebVersion.Bullseye
      , deb_profile = Profiles.Type.Devnet
      , deb_repo = DebianRepo.Type.Local
      , docker_publish = DockerPublish.Type.Disabled
      , deb_install_mode = DockerImage.DebianInstallMode.DownloadOnly
      , save_to_ci_cache = True
      , deb_legacy_version = "3.4.0-alpha1-compatible-ad13ff4"
      , size = Size.XLarge
      }

let archiveSpec =
      DockerImage.ReleaseSpec::{
      , deps = debDeps
      , service = Docker.Type.Archive { network = Network.Type.Devnet }
      , network = Network.Type.Devnet
      , deb_codename = DebianVersions.DebVersion.Bullseye
      , deb_profile = Profiles.Type.Devnet
      , deb_repo = DebianRepo.Type.Local
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
        [ DockerImage.generateStep daemonSpec // { env = disableGarEnv }
        , DockerImage.generateStep archiveSpec
        ]
      }
