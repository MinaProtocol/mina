-- Build only the mainnet .debs this transition test needs from the apps cache
-- inside the test job. This keeps the nightly test dependent on the bare app
-- build, like the devnet variant, instead of waiting on the global packaging
-- jobs for MinaArtifactMainnetBookworm and MinaArtifactGenericBookworm.

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Network = ../../Constants/Network.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Profiles = ../../Constants/Profiles.dhall

let network = Network.Type.Mainnet

let profile = Profiles.Type.Mainnet

let debVersion = DebianVersions.DebVersion.Bookworm

let dependsOnMainnet =
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
        , Artifacts.Type.DaemonPostfork { network = network }
        , Artifacts.Type.LogProc
        , Artifacts.Type.DaemonProfiled { profile = profile }
        ]
      , debVersion = debVersion
      }

let debianTokens =
      "${ArtifactPipelines.debianTokens
           buildSpec} daemon_${Network.lowerName
                                 network}_automode profile_${Profiles.lowerName
                                                               profile}_generic"

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.strictly (S.contains "Makefile")
      , S.exactly
          "buildkite/src/Jobs/Test/DebianAutomodeTransitionTestMainnet"
          "dhall"
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
        , name = "DebianAutomodeTransitionTestMainnet"
        , scope = [ PipelineScope.Type.MainlineNightly ]
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
                  ArtifactPipelines.buildDebianFromApps buildSpec debianTokens
                # RunInToolchain.runInToolchain
                    RunInToolchain.Config::{
                    , image = ContainerImages.minaToolchainBookworm.amd64
                    , environment = [ "LOCAL_DEB_SOURCE_DIR=_build" ]
                    , innerScript =
                        ''
                        ./buildkite/scripts/tests/debian-automode-transition-test.sh \
                          --codename bookworm \
                          --network ${Network.lowerName network}
                        ''
                    }
            , label = "Debian automode transition test (bookworm, mainnet)"
            , key = "debian-automode-transition-test-mainnet"
            , target = Size.Large
            , docker = None Docker.Type
            , depends_on = dependsOnMainnet
            }
        ]
      }
