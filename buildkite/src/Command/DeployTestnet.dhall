let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
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
            "cd coda-automation/terraform/testnets/${testnetName} && terraform init && terraform apply -auto-approve"
        ],
        label = "Deploy testnet: ${testnetName}",
        key = "deploy-testnet-${testnetName}",
        target = Size.Large,
        depends_on = dependsOn
      }
}
