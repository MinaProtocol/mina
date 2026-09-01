-- Installs and upgrades the mainnet .debs built by MinaArtifactMainnetBullseye,
-- so it belongs to the stage that builds them.
--
-- Hence the Packaging tag rather than Long: the nightly's LongAndVeryLong stage
-- used to select it while packaging did not run there, leaving it
-- waiting_failed on a dependency that was never scheduled. The devnet variant
-- of this test does not need the tag because it restores bare binaries from the
-- apps cache (appDependsOn) instead of installing a .deb.

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Profiles = ../../Constants/Profiles.dhall

let dependsOnMainnet =
        DebianVersions.dependsOn
          DebianVersions.DepsSpec::{
          , deb_version = DebianVersions.DebVersion.Bullseye
          , network = Network.Type.Mainnet
          , profile = Profiles.Type.Mainnet
          }
      # DebianVersions.dependsOn
          DebianVersions.DepsSpec::{
          , deb_version = DebianVersions.DebVersion.Bullseye
          }

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.strictly (S.contains "Makefile")
      , S.exactly
          "buildkite/src/Jobs/Test/DebianAutomodeTransitionTestMainnet"
          "dhall"
      , S.exactly "buildkite/scripts/tests/debian-automode-transition-test" "sh"
      , S.strictlyStart (S.contains "scripts/debian")
      , S.exactly "buildkite/scripts/cache/manager" "sh"
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "DebianAutomodeTransitionTestMainnet"
        , scope = [ PipelineScope.Type.MainlineNightly ]
        , tags =
          [ PipelineTag.Type.Packaging
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  RunInToolchain.Config::{
                  , image = ContainerImages.minaToolchainBullseye.amd64
                  , innerScript =
                      ''
                      ./buildkite/scripts/tests/debian-automode-transition-test.sh \
                        --codename bullseye \
                        --network mainnet
                      ''
                  }
            , label = "Debian automode transition test (bullseye, mainnet)"
            , key = "debian-automode-transition-test-mainnet"
            , target = Size.Large
            , docker = None Docker.Type
            , depends_on = dependsOnMainnet
            }
        ]
      }
