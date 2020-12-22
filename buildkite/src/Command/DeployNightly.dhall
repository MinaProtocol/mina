let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.runInDocker
            Cmd.Docker::{
              image = (../Constants/ContainerImages.dhall).codaToolchain
            }
            "cd coda-automation/terraform/testnets/nightly && terraform init; terraform destroy -auto-approve; terraform apply -auto-approve"
        ],
        label = "Deploy nightly",
        key = "deploy-nightly",
        target = Size.Large,
        depends_on = dependsOn
      }
}
