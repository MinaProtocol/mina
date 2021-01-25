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
            "if [ ! -f ${deployEnv} ]; then " ++
                "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${deployEnv} .; " ++
            "fi"
          ),
          Cmd.run (
            -- TODO: update to allow for custom post-apply step(s)
            "source ${deployEnv} && cd automation/terraform/testnets/${testnetName}" ++
            " && terraform init && terraform plan" ++
            " && terraform apply -auto-approve -var coda_image=\\\"gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH\\\"" ++
            " -var coda_archive_image=\\\"gcr.io/o1labs-192920/coda-archive:0.2.6-compatible\\\"" ++
            " && ${postDeploy}"
          )
        ],
        label = "Deploy testnet: ${testnetName}",
        key = "deploy-testnet-${testnetName}",
        target = Size.Large,
        depends_on = dependsOn
      }
}
