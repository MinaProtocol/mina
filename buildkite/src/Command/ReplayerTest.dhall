let B = ../../External/Buildkite.dhall

let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Cmd = ../Lib/Cmds.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run "./buildkite/scripts/replayer-test.sh"
        ],
        label = "Replayer test",
        key = "replayer-test",
        soft_fail = Some (B/SoftFail.Boolean True),
        target = Size.Large,
        depends_on = dependsOn
      }
}
