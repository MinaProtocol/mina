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
          -- create separate workspace based on build branch to isolate infrastructure states
          Cmd.run (
            "cd automation/terraform/testnets/${testnetName} && terraform init && (terraform workspace new \\\${BUILDKITE_BRANCH//_/-} || true)"
          ),
          Cmd.run (
            "if [ ! -f ${deployEnv} ]; then " ++
                "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${deployEnv} .; " ++
            "fi"
          ),
          Cmd.run (
            "source ${deployEnv} && terraform apply -auto-approve" ++
              " -var coda_image=gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH"
          ),
          Cmd.run (
            -- upload genesis_ledger and related generated json files
            "BUILDKITE_ARTIFACT_UPLOAD_DESTINATION=gs://buildkite_k8s/coda/shared/\\\${BUILDKITE_JOB_ID} buildkite-agent artifact upload \"*.json\""
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
