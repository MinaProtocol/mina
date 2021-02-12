let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall


let DeploySpec = {
  Type = {
    testnetLabel: Text,
    deployEnvFile : Text,
    workspace: Text,
    artifactPath: Text,
    postDeploy: Text,
    testnetDir: Text,
    deps : List Command.TaggedKey.Type
  },
  default = {
    testnetLabel = "ci-net",
    deployEnvFile = "DOCKER_DEPLOY_ENV",
    workspace = "\\\${BUILDKITE_BRANCH//[_\\/]/-}",
    artifactPath = "/tmp/artifacts",
    postDeploy = "echo 'Deployment successfull!'",
    testnetDir = "automation/terraform/testnets/ci-net",
    deps = [] : List Command.TaggedKey.Type
  }
}

in

{ 
  step = \(spec : DeploySpec.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run "cd ${spec.testnetDir} && terraform init",

          -- create separate workspace based on build branch to isolate infrastructure states
          Cmd.run "terraform workspace select ${spec.workspace} || terraform workspace new ${spec.workspace}",

          -- download deployment dependencies and ensure artifact DIR exists
          Cmd.run "artifact-cache-helper.sh ${spec.deployEnvFile}",
          Cmd.run "mkdir -p ${spec.artifactPath}",

          -- launch testnet based on deploy ENV
          Cmd.run (
            "source ${spec.deployEnvFile} && terraform apply -auto-approve" ++
              " -var coda_image=gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH" ++
              " -var ci_artifact_path=${spec.artifactPath}"
          ),

          -- upload/cache testnet genesis_ledger
          Cmd.run "artifact-cache-helper.sh ${spec.artifactPath}/genesis_ledger.json --upload",

          -- always execute post-deploy operation
          Cmd.run "${spec.postDeploy}"
        ],
        label = "Deploy testnet: ${spec.testnetLabel}",
        key = "deploy-${spec.testnetLabel}",
        target = Size.Large,
        depends_on = spec.deps
      },
  DeploySpec = DeploySpec
}