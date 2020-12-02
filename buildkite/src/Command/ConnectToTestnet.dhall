let Prelude = ../External/Prelude.dhall

let B = ../External/Buildkite.dhall
let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.runInDocker
            Cmd.Docker::{
              image = (../Constants/ContainerImages.dhall).ubuntu1804
            }
            "./buildkite/scripts/connect-to-testnet-on-develop.sh"
        ],
        label = "Connect to testnet",
        key = "connect-to-testnet",
        target = Size.Large,
        soft_fail = Some (B/SoftFail.Boolean True),
        depends_on = dependsOn
      }
}
