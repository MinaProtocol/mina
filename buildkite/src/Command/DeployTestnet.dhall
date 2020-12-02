let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall in

{ step = \(testnetName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.runInDocker
            Cmd.Docker::{
              image = (../Constants/ContainerImages.dhall).codaToolchain
            }
            "cd ${testnetName} && terraform apply"
        ],
        label = "Deploy testnet",
        key = "deploy-testnet",
        target = Size.Large,
        depends_on = dependsOn
      }
}
