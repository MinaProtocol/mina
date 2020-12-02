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
<<<<<<< HEAD
            "cd coda-automation/terraform/testnets/${testnetName} && terraform init && terraform apply -auto-approve; terraform destroy -auto-approve"
        ],
        label = "Deploy testnet: ${testnetName}",
=======
            "cd ${testnetName} && terraform apply"
        ],
        label = "Deploy testnet",
>>>>>>> 58cc509cb... add testnet deployment job to MinaArtifact pipeline
        key = "deploy-testnet",
        target = Size.Large,
        depends_on = dependsOn
      }
}
