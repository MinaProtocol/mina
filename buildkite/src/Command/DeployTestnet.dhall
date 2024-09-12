let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DeploySpec =
      { Type =
          { testnetLabel : Text
          , deployEnvFile : Text
          , workspace : Text
          , artifactPath : Text
          , postDeploy : Text
          , testnetDir : Text
          , deps : List Command.TaggedKey.Type
          }
      , default =
          { testnetLabel = "ci-net"
          , deployEnvFile = "export-git-env-vars.sh"
          , workspace = "\\\${BUILDKITE_BRANCH//[_\\/]/-}"
          , artifactPath = "/tmp/artifacts"
          , postDeploy = "echo 'Deployment successfull!'"
          , testnetDir = "automation/terraform/testnets/ci-net"
          , deps = [] : List Command.TaggedKey.Type
          }
      }

in  { step =
            \(spec : DeploySpec.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run "cd ${spec.testnetDir}"
                , Cmd.run "terraform init"
                , Cmd.run
                    "terraform workspace select ${spec.workspace} || terraform workspace new ${spec.workspace}"
                , Cmd.run "mkdir -p ${spec.artifactPath}"
                , Cmd.run "artifact-cache-helper.sh ${spec.deployEnvFile}"
                , Cmd.run "source ${spec.deployEnvFile}"
                , Cmd.run
                    (     "terraform apply -auto-approve"
                      ++  " -var mina_image=gcr.io/o1labs-192920/mina-daemon:\\\$MINA_DOCKER_TAG"
                      ++  " -var ci_artifact_path=${spec.artifactPath}"
                      ++  " || (terraform destroy -auto-approve && exit 1)"
                    )
                , Cmd.run
                    "artifact-cache-helper.sh ${spec.artifactPath}/genesis_ledger.json --upload"
                , Cmd.run "${spec.postDeploy}"
                ]
              , label = "Deploy ${spec.testnetLabel}"
              , key = "deploy-${spec.testnetLabel}"
              , target = Size.Large
              , depends_on = spec.deps
              }
    , DeploySpec = DeploySpec
    }
