-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.


let Prelude = ../External/Prelude.dhall

let List/concatMap = Prelude.List.concatMap

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
          , precomputed_block_prefix : Optional Text
          , size : Size
          }
      , default =
          { codenames = [ DebianVersions.DebVersion.Bullseye ]
          , network = Network.Type.TestnetGeneric
          , genesis_timestamp = Some "2024-04-07T11:45:00Z"
          , config_json_gz_url =
              "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz"
          , suffix = ""
          , version = "\\\$MINA_DEB_VERSION"
          , precomputed_block_prefix = None Text
          , size = Size.XLarge
          }
      }

let generateDockerForCodename =
          \(spec : Spec.Type)
      ->  \(codename : DebianVersions.DebVersion)
      ->  \(pipelineName : Text)
      ->  let image =
                Artifacts.fullDockerTag
                  Artifacts.Tag::{
                  , remove_profile_from_name = True
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
                , step_key_suffix =
                    "-${DebianVersions.lowerName codename}-docker-image"
                , size = spec.size
                }

          let dockerDaemonStep = DockerImage.stepKey dockerDaemonSpec

          let dependsOnTest =
                [ { name = pipelineName, key = dockerDaemonStep } ]

          let precomputed_block_prefix_arg =
                merge
                  { Some =
                          \(prefix : Text)
                      ->  "--precomputed-block-prefix " ++ prefix
                  , None = ""
                  }
                  spec.precomputed_block_prefix

          let genesis_timestamp =
                merge
                  { Some = \(ts : Text) -> [ "GENESIS_TIMESTAMP=${ts}" ]
                  , None = [] : List Text
                  }
                  spec.genesis_timestamp

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
                      # genesis_timestamp
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
                  , size = spec.size
                  , step_key_suffix =
                      "-${DebianVersions.lowerName codename}-docker-image"
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
                  , size = spec.size
                  , step_key_suffix =
                      "-${DebianVersions.lowerName codename}-docker-image"
                  }
              , Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.run
                        "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                      codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                    , Cmd.runInDocker
                        Cmd.Docker::{ image = image }
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed 's/B62qiburnzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmp7r7UN6X/B62qrTP88hjyU3hq6QNvFafX8sgHrsAW6v7tt5twrcugJM4bBV2eu9k/g' -i config.json && ! (FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                                                                                                                                                                spec.network}.json mina-verify-packaged-fork-config ${Network.lowerName
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
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                 spec.network}.json mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                   spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputed_block_prefix_arg}"
                    ]
                  , label = "Verify packaged artifacts"
                  , key =
                      "verify-packaged-artifacts-${DebianVersions.lowerName
                                                     codename}"
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
                    List/concatMap
                      DebianVersions.DebVersion
                      Command.Type
                      (     \(codename : DebianVersions.DebVersion)
                        ->  generateDockerForCodename spec codename pipelineName
                      )
                      spec.codenames
                }

let generate_hardfork_package =
          \(codenames : List DebianVersions.DebVersion)
      ->  \(network : Network.Type)
      ->  \(genesis_timestamp : Optional Text)
      ->  \(config_json_gz_url : Text)
      ->  \(suffix : Text)
      ->  \(version : Optional Text)
      ->  \(precomputed_block_prefix : Optional Text)
      ->  ( pipeline
              Spec::{
              , codenames = codenames
              , network = network
              , version =
                  merge
                    { Some = \(v : Text) -> v, None = "\\\$MINA_DEB_VERSION" }
                    version
              , genesis_timestamp = genesis_timestamp
              , config_json_gz_url = config_json_gz_url
              , suffix = suffix
              , precomputed_block_prefix = precomputed_block_prefix
              }
          ).pipeline

in  { generate_hardfork_package = generate_hardfork_package }
