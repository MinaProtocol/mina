let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall


let deployEnv = "DOCKER_DEPLOY_ENV"
-- testnet artifacts include: genesis ledgers, block producer keys,...
let testnetArtifactPath = "/tmp/artifacts" in

{ step = \(testnetName : Text) -> \(dependsOn : List Command.TaggedKey.Type) -> \(postDeploy : Text) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run (
            "cd automation/terraform/testnets/${testnetName} && terraform init" ++
            -- create separate workspace based on build branch to isolate infrastructure states
            " && (terraform workspace select \\\${BUILDKITE_BRANCH//_/-} || terraform workspace new \\\${BUILDKITE_BRANCH//_/-})"
          ),
          Cmd.run (
            "if [ ! -f ${deployEnv} ]; then " ++
                "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${deployEnv} .; " ++
            "fi"
          ),
          -- ensure artifact DIR exists
          Cmd.run "mkdir -p ${testnetArtifactPath}",
          Cmd.run (
            "source ${deployEnv} && terraform apply -auto-approve" ++
              " -var coda_image=gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH" ++
              " -var ci_artifact_path=${testnetArtifactPath}"
          ),
          Cmd.run (
            -- upload/cache testnet genesis_ledger
            "BUILDKITE_ARTIFACT_UPLOAD_DESTINATION=gs://buildkite_k8s/coda/shared/\\\${BUILDKITE_JOB_ID}" ++
              " pushd ${testnetArtifactPath} && buildkite-agent artifact upload \"genesis_ledger.json\" && popd"
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
