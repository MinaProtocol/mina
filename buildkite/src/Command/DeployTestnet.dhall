let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let defaultArtifactStep = { name = "MinaArtifact", key = "mina-docker-image" }

let deployEnv = "DOCKER_DEPLOY_ENV" in

{ step = \(testnetName : Text) -> \(dependsOn : List Command.TaggedKey.Type) -> \(postDeploy : Text) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run (
            "cd automation/terraform/testnets/${testnetName} && terraform init"
          ),
          Cmd.run (
            "if [ ! -f ${deployEnv} ]; then " ++
                "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${deployEnv} .; " ++
            "fi"
          ),
          Cmd.run (
            "set -euo pipefail; source ${deployEnv} && terraform apply -auto-approve" ++
              " -var coda_image=gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH"
          ),
          Cmd.run (
            -- upload genesis_ledger and related generated json files
            "cd ~ && buildkite/scripts/buildkite-artifact-helper.sh automation/terraform/testnets/${testnetName}/*.json"
          ),
          Cmd.run (
            -- always execute post-deploy operation
            "${postDeploy}"
          )
        ],
        label = "Deploy testnet: ${testnetName}",
        key = "deploy-testnet-${testnetName}",
        target = Size.Large,
        depends_on = dependsOn
      }
}
