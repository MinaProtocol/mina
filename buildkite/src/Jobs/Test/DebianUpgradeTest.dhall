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

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{
        , deb_version = DebianVersions.DebVersion.Bullseye
        , network = Network.Type.Devnet
        }

let buildTestCmd
    : Size -> Command.Type
    =     \(cmd_target : Size)
      ->  let key = "debian-upgrade-test"

          in  Command.build
                Command.Config::{
                , commands =
                    RunInToolchain.runInToolchainBullseye
                      Arch.Type.Amd64
                      ([] : List Text)
                      ''
                      ./buildkite/scripts/tests/debian-upgrade-test.sh \
                        --codename bullseye \
                        --channel devnet \
                        --package mina-devnet \
                        --new-debian "debians/bullseye/mina-devnet_*.deb"
                      ''
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
