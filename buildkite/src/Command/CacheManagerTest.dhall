let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Size = ./Size.dhall

let Arch = ../Constants/Arch.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let RunInToolchain = ./RunInToolchain.dhall

let testScript = "./buildkite/scripts/cache/tests/cache-parity-test.sh"

in  { bashStep =
        Command.build
          Command.Config::{
          , commands =
              RunInToolchain.runInDefaultToolchain ([] : List Text) testScript
          , label = "Cache manager tests (bash)"
          , key = "cache-manager-tests-bash"
          , target = Size.Small
          }
    , toolStep =
        Command.build
          Command.Config::{
          , commands =
            [ Cmd.runInDocker
                Cmd.Docker::{
                , image = ContainerImages.minaReleaseToolkit
                , extraEnv = [ "CACHE_ENGINE=buildkite-cache-manager" ]
                , platform = Arch.platform Arch.Type.Amd64
                }
                testScript
            ]
          , label = "Cache manager tests (buildkite-cache-manager)"
          , key = "cache-manager-tests-tool"
          , target = Size.Small
          }
    }
