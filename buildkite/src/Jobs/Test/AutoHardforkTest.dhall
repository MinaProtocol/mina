-- The dispatcher tests need a mina-daemon-auto-hardfork image, and used to get
-- one by depending on the packaging job's docker step. That made every PR that
-- touches src/ build the whole Debian + Docker artifact set, since selecting
-- this job pulls its dependency in (monorepo.sh phase-2 dependency resolution).
--
-- So the job now produces the image itself, on its own agent, in two commands:
--   1. build only the two .deb files the image installs from the freshly built
--      binaries in the apps cache (mina-<network>-postfork-mesa + mina-logproc),
--      reusing the exact packaging path the artifact job uses;
--   2. build the image from those .debs and load it locally -- no push, since
--      the tests run in the same step, on the same agent.
--
-- The legacy prefork .deb still comes from the cache's `legacy/debians` root:
-- it is a released pre-fork artifact, not something this build can produce.

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Docker = ../../Constants/Docker/Package.dhall

let DockerFromLocalDebs = ../../Command/DockerFromLocalDebs.dhall

let BaseImage = ../../Constants/Docker/BaseImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let Arch = ../../Constants/Arch.dhall

let Network = ../../Constants/Network.dhall

let network = Network.Type.Devnet

let profile = Profiles.Type.Devnet

let debVersion = DebianVersions.DebVersion.Bullseye

let arch = Arch.Type.Amd64

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/AutoHardforkTest" "dhall"
      , S.exactly_noext "dockerfiles/stages/daemon/4-auto-hardfork"
      , S.exactly_noext "dockerfiles/stages/1-base-deps"
      , S.exactly "scripts/hardfork/dispatcher" "sh"
      , S.exactly "scripts/hardfork/create_runtime_config" "sh"
      , S.strictlyStart (S.contains "buildkite/scripts/tests/hardfork")
      , S.exactly "scripts/docker/build" "sh"
      , S.exactly "scripts/debian/builder-helpers" "sh"
      , S.exactly "buildkite/scripts/debian/build-from-cache" "sh"
      , S.exactly "buildkite/scripts/docker/build-from-local-debs" "sh"
      , S.exactly "buildkite/src/Command/DockerFromLocalDebs" "dhall"
      , S.strictlyStart (S.contains "buildkite/scripts/apps")
      ]

let buildSpec =
      ArtifactPipelines.MinaBuildSpec::{
      , artifacts =
        [ Artifacts.Type.DaemonPostfork { network = network }
        , Artifacts.Type.LogProc
        ]
      , debVersion = debVersion
      , arch = arch
      }

let hardforkDocker =
      Docker.fullDockerTag
        Docker.Tag::{
        , package = Docker.Type.DaemonAutoHardfork { network = network }
        , network = network
        }

let imageSpec =
      DockerFromLocalDebs.Spec::{
      , service = Docker.Type.DaemonAutoHardfork { network = network }
      , network = network
      , profile = profile
      , baseImage = Some (BaseImage.imageFor debVersion arch)
      , legacyVersion = Some buildSpec.deb_legacy_version
      }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "AutoHardforkTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                  ArtifactPipelines.buildDebianFromApps
                    buildSpec
                    (ArtifactPipelines.debianTokens buildSpec)
                # [ DockerFromLocalDebs.buildImages debVersion [ imageSpec ]
                  , Cmd.run
                      "buildkite/scripts/tests/hardfork/dispatcher-tests.sh --docker ${hardforkDocker}"
                  ]
            , label = "Auto Hardfork: Dispatcher Tests"
            , key = "auto-hardfork-dispatcher-tests-bullseye"
            , target = Size.XLarge
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            , depends_on =
                DebianVersions.appDependsOn
                  DebianVersions.DepsSpec::{
                  , deb_version = debVersion
                  , network = network
                  , profile = profile
                  , arch = arch
                  }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "buildkite/scripts/tests/hardfork/create-runtime-config-tests.sh"
              ]
            , label = "Auto Hardfork: create_runtime_config Tests"
            , key = "auto-hardfork-create-runtime-config-tests"
            , target = Size.Small
            }
        ]
      }
