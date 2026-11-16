let Command = ./Base.dhall

let Size = ./Size.dhall

let RunInToolchain = ./RunInToolchain.dhall

let testScript = "./scripts/tests/deb-session/run-deb-session-tests.sh"

in  { step =
        Command.build
          Command.Config::{
          , commands =
              RunInToolchain.runInDefaultToolchain ([] : List Text) testScript
          , label = "Debian session tests (deb-toolkit)"
          , key = "debian-session-tests"
          , target = Size.Small
          }
    }
