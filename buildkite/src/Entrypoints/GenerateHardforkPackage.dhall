-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.

let SelectFiles = ../Lib/SelectFiles.dhall

let Cmd = ../Lib/Cmds.dhall

let Command = ../Command/Base.dhall

let MinaArtifact = ../Command/MinaArtifact.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let Size = ../Command/Size.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let DockerImage = ../Command/DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let Spec =
      { Type =
          { codenames : List DebianVersions.DebVersion
          , network : Network.Type
          , genesis_timestamp : Optional Text
          , config_json_gz_url : Text
          , version : Text
          , suffix : Text
          }
      , default =
          { codenames = [ DebianVersions.DebVersion.Bullseye ]
          , network = Network.Type.Base
          , genesis_timestamp = Some "2024-04-07T11:45:00Z"
          , config_json_gz_url =
              "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz"
          , suffix = ""
          }
      }

let generateDockerForCodename =
          \(spec : Spec.Type)
      ->  \(codename : DebianVersions.DebVersion)
      ->  \(pipelineName : Text)
      ->  let image =
                Artifacts.fullDockerTag
                  Artifacts.Tag::{
                  , version =
                      "${spec.version}-${DebianVersions.lowerName codename}"
                  , network = spec.network
                  }

          let profile = Profiles.fromNetwork spec.network

          let dockerDaemonSpec =
                DockerImage.ReleaseSpec::{
                , deps =
                  [ { name = pipelineName
                    , key = "build-deb-pkg-${DebianVersions.lowerName codename}"
                    }
                  ]
                , service = Artifacts.Type.Daemon
                , network = spec.network
                , deb_codename = codename
                , deb_profile = profile
                , deb_repo = DebianRepo.Type.Local
                , deb_suffix = Some "hardfork"
                }

          let dockerDaemonStep = DockerImage.stepKey dockerDaemonSpec

          let dependsOnTest =
                [ { name = pipelineName, key = dockerDaemonStep } ]

          in  [ MinaArtifact.buildArtifacts
                  MinaArtifact.MinaBuildSpec::{
                  , artifacts =
                    [ Artifacts.Type.LogProc
                    , Artifacts.Type.DaemonLegacyHardfork
                    , Artifacts.Type.Archive
                    , Artifacts.Type.Rosetta
                    , Artifacts.Type.ZkappTestTransaction
                    ]
                  , debVersion = codename
                  , profile = profile
                  , network = spec.network
                  , prefix = pipelineName
                  , suffix = Some "-${DebianVersions.lowerName codename}"
                  , extraBuildEnvs =
                    [ "NETWORK_NAME=${Network.lowerName spec.network}"
                    , "CONFIG_JSON_GZ_URL=${spec.config_json_gz_url}"
                    ]
                  , buildScript =
                      "./buildkite/scripts/hardfork/build-packages.sh"
                  }
              , DockerImage.generateStep dockerDaemonSpec
              , DockerImage.generateStep
                  DockerImage.ReleaseSpec::{
                  , deps =
                    [ { name = pipelineName
                      , key =
                          "build-deb-pkg-${DebianVersions.lowerName codename}"
                      }
                    ]
                  , service = Artifacts.Type.Archive
                  , network = spec.network
                  , deb_codename = codename
                  , deb_profile = profile
                  , deb_repo = DebianRepo.Type.Local
                  }
              , DockerImage.generateStep
                  DockerImage.ReleaseSpec::{
                  , deps =
                    [ { name = pipelineName
                      , key =
                          "build-deb-pkg-${DebianVersions.lowerName codename}"
                      }
                    ]
                  , service = Artifacts.Type.Rosetta
                  , network = spec.network
                  , deb_profile = profile
                  , deb_repo = DebianRepo.Type.Local
                  , deb_codename = codename
                  , deb_suffix = Some "hardfork"
                  }
              , Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.run
                        "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                      codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                    , Cmd.runInDocker
                        Cmd.Docker::{ image = image }
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed 's/B62qiburnzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmp7r7UN6X/B62qrTP88hjyU3hq6QNvFafX8sgHrsAW6v7tt5twrcugJM4bBV2eu9k/g' -i config.json && ! (FORKING_FROM_CONFIG_JSON=config.json mina-verify-packaged-fork-config ${Network.lowerName
                                                                                                                                                                                                                                                                                                                               spec.network} config.json /workdir/verification)"
                    ]
                  , label =
                      "Assert corrupted packaged artifacts are unverifiable"
                  , key =
                      "assert-unverify-corrupted-packaged-artifacts-${DebianVersions.lowerName
                                                                        codename}"
                  , target = Size.XLarge
                  , depends_on = dependsOnTest
                  }
              , Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.run
                        "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                      codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                    , Cmd.runInDocker
                        Cmd.Docker::{ image = image }
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=config.json mina-verify-packaged-fork-config ${Network.lowerName
                                                                                                                                                                                spec.network} config.json /workdir/verification"
                    ]
                  , label = "Verify packaged artifacts"
                  , key = "verify-packaged-artifacts"
                  , target = Size.XLarge
                  , depends_on = dependsOnTest
                  }
              ]

let pipeline =
          \(spec : Spec.Type)
      ->  let pipelineName = "GenerateHardforkPackage"

          in  Pipeline.build
                Pipeline.Config::{
                , spec = JobSpec::{
                  , dirtyWhen = [ SelectFiles.everything ]
                  , path = "Entrypoints"
                  , name = pipelineName
                  , tags =
                    [ PipelineTag.Type.Release
                    , PipelineTag.Type.Hardfork
                    , PipelineTag.Type.Long
                    ]
                  }
                , steps =
                    generateDockerForCodename
                      spec
                      DebianVersions.DebVersion.Focal
                      pipelineName
                }

let generate_hardfork_package =
          \(codenames : List DebianVersions.DebVersion)
      ->  \(network : Network.Type)
      ->  \(genesis_timestamp : Optional Text)
      ->  \(config_json_gz_url : Text)
      ->  \(suffix : Text)
      ->  ( pipeline
              Spec::{
              , codenames = codenames
              , network = network
              , version = "\\\$MINA_DEB_VERSION"
              , genesis_timestamp = genesis_timestamp
              , config_json_gz_url = config_json_gz_url
              , suffix = suffix
              }
          ).pipeline

in  { generate_hardfork_package = generate_hardfork_package }
