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

let DebianChannel = ../Constants/DebianChannel.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let Publish = ../Command/Packages/Publish.dhall

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
          , network = Network.Type.Berkeley
          , genesis_timestamp = Some "2024-04-07T11:45:00Z"
          , config_json_gz_url =
              "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz"
          , suffix = "hardfork"
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
                }

          let dockerDaemonStep = DockerImage.stepKey dockerDaemonSpec

          let dependsOnTest =
                [ { name = pipelineName, key = dockerDaemonStep } ]

          in  [ MinaArtifact.buildArtifacts
                  MinaArtifact.MinaBuildSpec::{
                  , artifacts =
                    [ Artifacts.Type.LogProc
                    , Artifacts.Type.Daemon
                    , Artifacts.Type.Archive
                    , Artifacts.Type.Rosetta
                    ]
                  , debVersion = codename
                  , profile = profile
                  , network = spec.network
                  , buildScript =
                      "./buildkite/scripts/hardfork/build-release.sh"
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
                  }
              , Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.runInDocker
                        Cmd.Docker::{ image = image }
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed -e '0,/20.000001/{s/20.000001/20.01/}' -i config.json && ! (mina-verify-packaged-fork-config ${Network.lowerName
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
                    [ Cmd.runInDocker
                        Cmd.Docker::{ image = image }
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config ${Network.lowerName
                                                                                                                                           spec.network} config.json /workdir/verification"
                    ]
                  , label = "Verify packaged artifacts"
                  , key = "verify-packaged-artifacts"
                  , target = Size.XLarge
                  , depends_on = dependsOnTest
                  }
              ]

let new_tags =
          \(codename : DebianVersions.DebVersion)
      ->  \(channel : DebianChannel.Type)
      ->  \(branch : Text)
      ->  \(profile : Profiles.Type)
      ->  \(commit : Text)
      ->  \(latestGitTag : Text)
      ->  \(todayDate : Text)
      ->  [ "${latestGitTag}-${commit}-${Profiles.toSuffixLowercase profile}" ]

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  let pipelineName =
                "MinaArtifactHardfork${Network.capitalName
                                         spec.network}${spec.suffix}"

          let targetVersion =
                    \(codename : DebianVersions.DebVersion)
                ->  \(channel : DebianChannel.Type)
                ->  \(branch : Text)
                ->  \(profile : Profiles.Type)
                ->  \(commit : Text)
                ->  \(latestGitTag : Text)
                ->  \(todayDate : Text)
                ->  "${spec.version}"

          in  Pipeline.Config::{
              , spec = JobSpec::{
                , dirtyWhen = [ SelectFiles.everything ]
                , path = "Release"
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
                  # Publish.publish
                      Publish.Spec::{
                      , artifacts =
                        [ Artifacts.Type.Daemon
                        , Artifacts.Type.Archive
                        , Artifacts.Type.Rosetta
                        , Artifacts.Type.LogProc
                        ]
                      , networks = [ spec.network ]
                      , debian_repo = DebianRepo.Type.Unstable
                      , codenames = spec.codenames
                      , build_id = "\\\$BUILDKITE_BUILD_ID"
                      , profile = Profiles.fromNetwork spec.network
                      , source_version = "\\\$MINA_DEB_VERSION"
                      , target_version = targetVersion
                      , new_docker_tags = new_tags
                      , depends_on =
                        [ { name = pipelineName, key = "build-deb-pkg" } ]
                      }
              }

let generate_hardfork_package =
          \(codenames : List DebianVersions.DebVersion)
      ->  \(network : Network.Type)
      ->  \(genesis_timestamp : Optional Text)
      ->  \(config_json_gz_url : Text)
      ->  \(suffix : Text)
      ->  pipeline
            Spec::{
            , codenames = codenames
            , network = network
            , version = "\\\$MINA_DOCKER_TAG"
            , genesis_timestamp = genesis_timestamp
            , config_json_gz_url = config_json_gz_url
            , suffix = suffix
            }

in  { generate_hardfork_package = generate_hardfork_package }
