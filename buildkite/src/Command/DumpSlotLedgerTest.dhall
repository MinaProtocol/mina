let B = ../External/Buildkite.dhall

let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run "./buildkite/scripts/dump-slot-test.sh"
        ],
        label = "Dump Slot test",
        key = "dump-slot-ledger-test",
        target = Size.Large,
        depends_on = dependsOn
      }
}
