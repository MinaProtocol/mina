let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let Arch = ../../Constants/Arch.dhall

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
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchainBullseye
                  Arch.Type.Amd64
                  ([] : List Text)
                  ''
                  ./buildkite/scripts/tests/debian-automode-transition-test.sh \
                    --codename bullseye \
                    --network mainnet
                  ''
            , label = "Debian automode transition test (bullseye, mainnet)"
            , key = "debian-automode-transition-test-mainnet"
            , target = Size.Large
            , docker = None Docker.Type
            , depends_on = dependsOnMainnet
            }
        ]
      }
