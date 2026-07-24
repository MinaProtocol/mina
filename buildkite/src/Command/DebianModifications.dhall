let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Size = ./Size.dhall

let Arch = ../Constants/Arch.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let RunInToolchain = ./RunInToolchain.dhall

let testScript = "./scripts/debian/session/tests/run-deb-session-tests.sh"

in  { step =
        Command.build
          Command.Config::{
          , commands =
              RunInToolchain.runInDefaultToolchain ([] : List Text) testScript
          , label = "Debian session script tests"
          , key = "debian-session-tests"
          , target = Size.Small
          }
    , debToolkitStep =
        Command.build
          Command.Config::{
          , commands =
            [ Cmd.runInDocker
                Cmd.Docker::{
                , image = ContainerImages.minaReleaseToolkit
                , extraEnv = [ "SESSION_ENGINE=deb-toolkit" ]
                , platform = Arch.platform Arch.Type.Amd64
                }
                testScript
            ]
          , label = "Debian session tests (deb-toolkit)"
          , key = "debian-session-tests-deb-toolkit"
          , target = Size.Small
          }
    }
