let Prelude = ../External/Prelude.dhall
let B = ../External/Buildkite.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Cmd = ../Lib/Cmds.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.runInDocker
            Cmd.Docker::{
              image = (../Constants/ContainerImages.dhall).minaDaemonBerkeley,
              entrypoint = " --entrypoint=/usr/bin/dumb-init"
            }
            "./buildkite/scripts/connect-to-berkeley.sh"
        ],
        label = "Connect to Berkeley",
        soft_fail = Some (B/SoftFail.Boolean True),
        key = "connect-to-berkeley",
        target = Size.Large,
        depends_on = dependsOn
      }
}
