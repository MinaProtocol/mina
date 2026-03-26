let PipelineTag = ../../Pipeline/Tag.dhall

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

let dependsOnDevnet =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{
        , deb_version = DebianVersions.DebVersion.Bullseye
        , network = Network.Type.Devnet
        }

let dependsOnMainnet =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{
        , deb_version = DebianVersions.DebVersion.Bullseye
        , network = Network.Type.Mainnet
        , profile = Profiles.Type.Mainnet
        }

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
                    RunInToolchain.runInToolchainBullseye
                      Arch.Type.Amd64
                      ([] : List Text)
                      ''
                      ./buildkite/scripts/tests/debian-automode-transition-test.sh \
                        --codename bullseye \
                        --network ${network}
                      ''
                , label =
                    "Debian automode transition test (bullseye, ${network})"
                , key = key
                , target = cmd_target
                , docker = None Docker.Type
                , depends_on = deps
                }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let dirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.strictly (S.contains "Makefile")
                , S.exactly
                    "buildkite/src/Jobs/Test/DebianAutomodeTransitionTest"
                    "dhall"
                , S.exactly
                    "buildkite/scripts/tests/debian-automode-transition-test"
                    "sh"
                , S.strictlyStart (S.contains "scripts/debian")
                , S.exactly "buildkite/scripts/cache/manager" "sh"
                ]

          in  JobSpec::{
              , dirtyWhen = dirtyWhen
              , path = "Test"
              , name = "DebianAutomodeTransitionTest"
              , tags =
                [ PipelineTag.Type.Long
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              }
      , steps =
        [ buildTestCmd "devnet" "devnet" dependsOnDevnet Size.Large
        , buildTestCmd "mainnet" "mainnet" dependsOnMainnet Size.Large
        ]
      }
