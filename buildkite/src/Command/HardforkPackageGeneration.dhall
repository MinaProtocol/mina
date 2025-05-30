let Prelude = ../External/Prelude.dhall

let Optional/toList = Prelude.Optional.toList

let Optional/map = Prelude.Optional.map

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let S = ../Lib/SelectFiles.dhall

let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let DockerImage = ./DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Profiles = ../Constants/Profiles.dhall

let Toolchain = ../Constants/Toolchain.dhall

let Network = ../Constants/Network.dhall

let Spec =
      { Type =
          { codename : DebianVersions.DebVersion
          , network : Network.Type
          , genesis_timestamp : Optional Text
          , config_json_gz_url : Text
          , profile : Profiles.Type
          , suffix : Text
          }
      , default =
          { codename = DebianVersions.DebVersion.Bullseye
          , network = Network.Type.Berkeley
          , genesis_timestamp = Some "2024-04-07T11:45:00Z"
          , config_json_gz_url =
              "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz"
          , profile = Profiles.Type.Standard
          , suffix = "hardfork"
          }
      }

let spec_to_envs
    : Spec.Type -> List Text
    =     \(spec : Spec.Type)
      ->    [ "NETWORK_NAME=${Network.lowerName spec.network}"
            , "TESTNET_NAME=${Network.lowerName spec.network}-${spec.suffix}"
            , "CONFIG_JSON_GZ_URL=${spec.config_json_gz_url}"
            ]
          # Optional/toList
              Text
              ( Optional/map
                  Text
                  Text
                  (     \(genesis_timestamp : Text)
                    ->  "GENESIS_TIMESTAMP=${genesis_timestamp}"
                  )
                  spec.genesis_timestamp
              )

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  let profile = spec.profile

          let network = Network.lowerName spec.network

          let network_name = "${network}-hardfork"

          let pipelineName =
                "MinaArtifactHardfork${DebianVersions.capitalName
                                         spec.codename}${Profiles.toSuffixUppercase
                                                           profile}"

          let generateLedgersJobKey = "generate-ledger-tars-from-config"

          let debVersion = spec.codename

          let image =
                "gcr.io/o1labs-192920/mina-daemon:\${BUILDKITE_COMMIT:0:7}-${DebianVersions.lowerName
                                                                               debVersion}-${network_name}"

          let dockerSpec =
                DockerImage.ReleaseSpec::{
                , deps =
                  [ { name = pipelineName, key = generateLedgersJobKey } ]
                , service = Artifacts.Type.Daemon
                , network = network_name
                , deb_codename = debVersion
                , deb_profile = profile
                , deb_repo = DebianRepo.Type.Local
                }

          in  Pipeline.Config::{
              , spec = JobSpec::{
                , dirtyWhen = [ S.everything ]
                , path = "Release"
                , name = pipelineName
                , tags =
                  [ PipelineTag.Type.Release
                  , PipelineTag.Type.Hardfork
                  , PipelineTag.Type.Long
                  ]
                , mode = PipelineMode.Type.Stable
                }
              , steps =
                [ Command.build
                    Command.Config::{
                    , commands =
                          Toolchain.runner
                            debVersion
                            (   [ "AWS_ACCESS_KEY_ID"
                                , "AWS_SECRET_ACCESS_KEY"
                                , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                                , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                                , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                         debVersion}"
                                ]
                              # spec_to_envs spec
                            )
                            "./buildkite/scripts/build-hardfork-package.sh"
                        # [ Cmd.run
                              "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                                debVersion}"
                          ]
                    , label =
                        "Build Mina Hardfork Package for ${DebianVersions.capitalName
                                                             debVersion}"
                    , key = generateLedgersJobKey
                    , target = Size.XLarge
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                        Toolchain.runner
                          debVersion
                          [ "AWS_ACCESS_KEY_ID"
                          , "AWS_SECRET_ACCESS_KEY"
                          , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                   debVersion}"
                          ]
                          "./buildkite/scripts/debian/publish.sh"
                    , label =
                        "Publish Mina for ${DebianVersions.capitalName
                                              debVersion} Hardfork"
                    , depends_on =
                      [ { name = pipelineName, key = generateLedgersJobKey } ]
                    , key = "publish-hardfork-deb-pkg"
                    , target = Size.Small
                    }
                , DockerImage.generateStep dockerSpec
                , Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed -e '0,/20.000001/{s/20.000001/20.01/}' -i config.json && ! (mina-verify-packaged-fork-config ${network} config.json /workdir/verification)"
                      ]
                    , label =
                        "Assert corrupted packaged artifacts are unverifiable"
                    , key = "assert-unverify-corrupted-packaged-artifacts"
                    , target = Size.XLarge
                    , depends_on =
                      [ { name = pipelineName
                        , key = DockerImage.stepKey dockerSpec
                        }
                      ]
                    , if = None B/If
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config ${network} config.json /workdir/verification"
                      ]
                    , label = "Verify packaged artifacts"
                    , key = "verify-packaged-artifacts"
                    , target = Size.XLarge
                    , depends_on =
                      [ { name = pipelineName
                        , key = DockerImage.stepKey dockerSpec
                        }
                      ]
                    , if = None B/If
                    }
                , DockerImage.generateStep
                    DockerImage.ReleaseSpec::{
                    , deps =
                      [ { name = pipelineName, key = generateLedgersJobKey } ]
                    , service = Artifacts.Type.Archive
                    , network = network_name
                    , deb_codename = debVersion
                    , deb_profile = profile
                    , deb_repo = DebianRepo.Type.Local
                    }
                , DockerImage.generateStep
                    DockerImage.ReleaseSpec::{
                    , deps =
                      [ { name = pipelineName, key = generateLedgersJobKey } ]
                    , service = Artifacts.Type.Rosetta
                    , network = network_name
                    , deb_repo = DebianRepo.Type.Local
                    , deb_codename = debVersion
                    }
                ]
              }

in  { pipeline = pipeline, Spec = Spec }
