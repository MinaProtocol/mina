let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let DockerImage = ../../Command/DockerImage.dhall

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let DockerPublish = ../../Constants/DockerPublish.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Network = ../../Constants/Network.dhall

let network = Network.Type.Devnet

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/AutoHardforkTest" "dhall"
      , S.exactly_noext "dockerfiles/Dockerfile-mina-daemon-auto-hardfork"
      , S.exactly "scripts/hardfork/dispatcher" "sh"
      , S.exactly "scripts/hardfork/create_runtime_config" "sh"
      , S.exactly "buildkite/scripts/tests/hardfork/dispatcher-tests" "sh"
      , S.exactly
          "buildkite/scripts/tests/hardfork/create-runtime-config-tests"
          "sh"
      , S.exactly "scripts/docker/build" "sh"
      , S.exactly "scripts/debian/builder-helpers" "sh"
      , S.exactly "buildkite/scripts/docker/load_from_cache" "sh"
      ]

let imageSpec =
      DockerImage.ReleaseSpec::{
      , deps = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}
      , service = Artifacts.Type.DaemonAutoHardfork
      , network = network
      , deb_codename = DebianVersions.DebVersion.Bookworm
      , deb_profile = Profiles.Type.Devnet
      , deb_repo = DebianRepo.Type.Local
      , deb_legacy_version =
          ArtifactPipelines.MinaBuildSpec.default.deb_legacy_version
      , docker_publish = DockerPublish.Type.Disabled
      , save_to_ci_cache = True
      , size = Size.XLarge
      }

let hardforkDocker =
          "${DockerRepo.show
               DockerRepo.Type.InternalEurope}/${Artifacts.dockerName
                                                   Artifacts.Type.DaemonAutoHardfork}"
      ++  ":\\\${GITHASH}-bookworm-${Network.lowerName network}"

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
        [ DockerImage.generateStep imageSpec
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "export MINA_DEB_CODENAME=bookworm && source ./buildkite/scripts/export-git-env-vars.sh"
              , Cmd.run
                  "./buildkite/scripts/docker/load_from_cache.sh ${hardforkDocker}"
              , Cmd.run
                  "buildkite/scripts/tests/hardfork/dispatcher-tests.sh --docker ${hardforkDocker}"
              ]
            , label = "Auto Hardfork: Dispatcher Tests"
            , key = "auto-hardfork-dispatcher-tests-bookworm"
            , target = Size.Small
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            , depends_on =
              [ { name = "AutoHardforkTest"
                , key = DockerImage.stepKey imageSpec
                }
              ]
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
