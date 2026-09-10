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

let network = Network.Type.Devnet

let profile = Profiles.Type.Devnet

let debVersion = DebianVersions.DebVersion.Noble

let dependsOn =
      DebianVersions.appDependsOn
        DebianVersions.DepsSpec::{
        , deb_version = debVersion
        , network = network
        , profile = profile
        }

let buildSpec =
      ArtifactPipelines.PackagingSpec::{
      , artifacts =
        [ Artifacts.Type.DaemonGeneric
        , Artifacts.Type.Daemon { network = network }
        , Artifacts.Type.LogProc
        , Artifacts.Type.DaemonProfiled { profile = profile }
        ]
      , debVersion = debVersion
      }

let buildTestCmd
    : Size -> Command.Type
    =     \(cmd_target : Size)
      ->  let key = "debian-upgrade-test"

          in  Command.build
                Command.Config::{
                , commands =
                      ArtifactPipelines.buildDebianFromApps
                        buildSpec
                        (ArtifactPipelines.debianTokens buildSpec)
                    # RunInToolchain.runInToolchain
                        RunInToolchain.Config::{
                        , image = ContainerImages.minaToolchainNoble.amd64
                        , environment = [ "LOCAL_DEB_SOURCE_DIR=_build" ]
                        , innerScript =
                            ''
                            ./buildkite/scripts/tests/debian-upgrade-test.sh \
                              --codename bullseye \
                              --channel alpha \
                              --package mina-devnet \
                              --install-packages mina-generic,mina-devnet-config \
                              --new-debian "debians/bullseye/mina-generic_*.deb"
                            ''
                        }
                , label = "Debian upgrade test (bullseye)"
                , key = key
                , target = cmd_target
                , docker = None Docker.Type
                , depends_on = dependsOn
                }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let dirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.strictly (S.contains "Makefile")
                , S.exactly "buildkite/src/Jobs/Test/DebianUpgradeTest" "dhall"
                , S.exactly "buildkite/scripts/tests/debian-upgrade-test" "sh"
                , S.strictlyStart (S.contains "scripts/debian")
                , S.exactly "buildkite/scripts/cache/manager" "sh"
                ]

          in  JobSpec::{
              , dirtyWhen = dirtyWhen
              , path = "Test"
              , name = "DebianUpgradeTest"
              , tags =
                [ PipelineTag.Type.Long
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              }
      , steps = [ buildTestCmd Size.Large ]
      }
