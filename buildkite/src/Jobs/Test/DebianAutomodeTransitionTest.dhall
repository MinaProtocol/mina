let PipelineTag = ../../Pipeline/Tag.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Profiles = ../../Constants/Profiles.dhall

let Network = ../../Constants/Network.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let devnet = Network.Type.Devnet

let profile = Profiles.Type.Devnet

let debVersion = DebianVersions.DebVersion.Bullseye

let dependsOnDevnet =
      DebianVersions.appDependsOn
        DebianVersions.DepsSpec::{
        , deb_version = debVersion
        , network = devnet
        , profile = profile
        }

let buildSpec =
      ArtifactPipelines.MinaBuildSpec::{
      , artifacts =
        [ Artifacts.Type.DaemonGeneric
        , Artifacts.Type.Daemon { network = devnet }
        , Artifacts.Type.DaemonPostfork { network = devnet }
        , Artifacts.Type.LogProc
        , Artifacts.Type.DaemonProfiled { profile = profile }
        ]
      , debVersion = debVersion
      }

let debianTokens =
      "${ArtifactPipelines.debianTokens
           buildSpec} daemon_devnet_automode profile_devnet_generic"

let buildTestCmd
    : Text -> Text -> List { name : Text, key : Text } -> Size -> Command.Type
    =     \(network : Text)
      ->  \(keySuffix : Text)
      ->  \(deps : List { name : Text, key : Text })
      ->  \(cmd_target : Size)
      ->  let key = "debian-automode-transition-test-${keySuffix}"

          in  Command.build
                Command.Config::{
                , commands =
                      ArtifactPipelines.buildDebianFromApps
                        buildSpec
                        debianTokens
                    # RunInToolchain.runInToolchain
                        RunInToolchain.Config::{
                        , image = ContainerImages.minaToolchainBullseye.amd64
                        , environment = [ "LOCAL_DEB_SOURCE_DIR=_build" ]
                        , innerScript =
                            ''
                            ./buildkite/scripts/tests/debian-automode-transition-test.sh \
                              --codename bullseye \
                              --network ${network}
                            ''
                        }
                , label =
                    "Debian automode transition test (bullseye, ${network})"
                , key = key
                , target = cmd_target
                , docker = None Docker.Type
                , depends_on = deps
                }

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.strictly (S.contains "Makefile")
      , S.strictlyStart (S.contains "mk/")
      , S.exactly "buildkite/src/Jobs/Test/DebianAutomodeTransitionTest" "dhall"
      , S.exactly "buildkite/scripts/tests/debian-automode-transition-test" "sh"
      , S.strictlyStart (S.contains "scripts/debian")
      , S.exactly "buildkite/scripts/cache/manager" "sh"
      , S.exactly "buildkite/scripts/debian/fetch_debs" "sh"
      , S.exactly "buildkite/scripts/debian/build-from-cache" "sh"
      , S.exactly "buildkite/src/Command/MinaArtifact" "dhall"
      , S.strictlyStart (S.contains "buildkite/scripts/apps")
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "DebianAutomodeTransitionTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ buildTestCmd "devnet" "devnet" dependsOnDevnet Size.Large ]
      }
