let Command = ./Base.dhall

let Size = ./Size.dhall

let RunInToolchain = ./RunInToolchain.dhall

in  { step =
        Command.build
          Command.Config::{
          , commands =
              RunInToolchain.runInToolchain
                ([] : List Text)
                "./scripts/debian/session/tests/run-deb-session-tests.sh"
          , label = "Debian session script tests"
          , key = "debian-session-tests"
          , target = Size.Small
          }
    }
