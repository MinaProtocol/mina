let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall in

{ step = \(testnetName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run (
            -- TODO: update to allow for custom post-apply step(s)
            "cd automation/terraform/testnets/${testnetName} && terraform init" ++
            " && terraform apply -auto-approve -var coda_archive_image='gcr.io/o1labs-192920/coda-archive:0.2.6-compatible'" ++
            "; terraform destroy -auto-approve"
          )
        ],
        label = "Deploy testnet: ${testnetName}",
        key = "deploy-testnet-${testnetName}",
        target = Size.Large,
        depends_on = dependsOn
      }
}
