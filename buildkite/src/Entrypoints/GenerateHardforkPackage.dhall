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

let RunInToolchain = ../Command/RunInToolchain.dhall

let Spec =
      { Type =
          { codenames : List DebianVersions.DebVersion
          , network : Network.Type
          , genesis_timestamp : Optional Text
          , config_json_gz_url : Text
          , version : Text
          , suffix : Text
          , precomputed_block_prefix : Optional Text
          , use_artifacts_from_buildkite_build : Optional Text
          , size : Size
          }
      , default =
          { codenames = [ DebianVersions.DebVersion.Bullseye ]
          , network = Network.Type.Berkeley
          , genesis_timestamp = Some "2024-04-07T11:45:00Z"
          , config_json_gz_url =
              "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz"
          , suffix = ""
          , version = "\\\$MINA_DEB_VERSION"
          , precomputed_block_prefix = None Text
          , use_artifacts_from_buildkite_build = None Text
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

          let lowerNameCodename = DebianVersions.lowerName codename

          let artifactsGenKey =
                "build-or-download-artifacts-${lowerNameCodename}"

          let tarballGenKey =
                "generate-hardfork-tarballs-${lowerNameCodename}"

          let tarballUploadKey =
                "upload-hardfork-tarballs-${lowerNameCodename}"

          let buildHfDebian =
                "build-hf-debian-${lowerNameCodename}"

          let dependsOnTarballs =
                [ { name = pipelineName, key = tarballGenKey } ]

          let dependsOnUpload =
                [ { name = pipelineName, key = tarballUploadKey } ]

          let dependsOnBuildHfDebian =
                [ { name = pipelineName, key = buildHfDebian } ]

          let dependsOnArtifacts =
                [ { name = pipelineName, key = artifactsGenKey } ]

          let dockerDaemonSpec =
                DockerImage.ReleaseSpec::{
                , deps = dependsOnBuildHfDebian
                , service = Artifacts.Type.Daemon
                , network = spec.network
                , deb_codename = codename
                , deb_profile = profile
                , deb_repo = DebianRepo.Type.Local
                , deb_suffix = Some "hardfork"
                , step_key_suffix =
                    "-${lowerNameCodename}-docker-image"
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

          let buildOrGetArtifacts =
                merge
                  { Some =
                          \(build : Text)
                      ->  []: List Command.Type

                  , None = [
                    MinaArtifact.buildArtifacts
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
                      , prefix = pipelineName
                      , suffix = Some "-${lowerNameCodename}"
                      }
                    ]
                  }
                  spec.use_artifacts_from_buildkite_build

          let useArtifactsEnvVar =
                merge
                  { Some =
                          \(build : Text)
                      ->  "CACHED_BUILDKITE_BUILD_ID=${build} "
                          ++ build
                  , None = "CACHED_BUILDKITE_BUILD_ID=\\\$BUILDKITE_BUILD_ID"
                  }
                  spec.use_artifacts_from_buildkite_build


          let generateTarballsCommand =
              Command.build
                Command.Config::{
                  , commands =
                      RunInToolchain.runInToolchain
                          ([] : List Text)
                          ("./buildkite/scripts/hardfork/generate-tarballs.sh "
                              ++ "--network ${Network.lowerName spec.network} "
                              ++ "--config-url ${spec.config_json_gz_url} "
                          )
                  , label = "Generate hardfork tarballs for ${lowerNameCodename}"
                  , key = tarballGenKey
                  , depends_on = dependsOnArtifacts
                  , target = Size.Large
                  }

          in  buildOrGetArtifacts # [
              generateTarballsCommand
              , Command.build
                Command.Config::{
                  , commands =
                      RunInToolchain.runInToolchain
                          ([] : List Text)
                          "./buildkite/scripts/hardfork/upload-ledger-tarballs-to-s3.sh"
                  , label = "Upload hardfork tarballs for ${lowerNameCodename}"
                  , key = tarballUploadKey
                  , target = Size.Large
                  , depends_on = dependsOnTarballs
                  }
              , Command.build
                Command.Config::{
                  , commands =
                      RunInToolchain.runInToolchain
                          ([] : List Text)
                          "./buildkite/scripts/hardfork/generate-tarballs-with-legacy-app.sh"
                  , label = "Legacy hardfork tarballs for ${lowerNameCodename}"
                  , key = tarballGenKey ++ "-legacy"
                  , target = Size.Large
                  }
              , Command.build
                Command.Config::{
                  , commands =
                      RunInToolchain.runInToolchain
                          [ "NETWORK_NAME=${Network.lowerName spec.network}"
                          , "CONFIG_JSON_GZ_URL=${spec.config_json_gz_url}"
                          , "CACHED_BUILDKITE_BUILD_ID=${useArtifactsEnvVar}"
                          , "CODENAME=${lowerNameCodename}"
                          ]
                          "./buildkite/scripts/hardfork/prepare-hf-debian.sh"
                  , label = "Create hardfork packages for ${lowerNameCodename}"
                  , key = buildHfDebian
                  , target = Size.Large
                  , depends_on = dependsOnTarballs
                  }
              , DockerImage.generateStep dockerDaemonSpec
              , DockerImage.generateStep
                  DockerImage.ReleaseSpec::{
                  , deps = dependsOnBuildHfDebian
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
                  , deps = dependsOnBuildHfDebian
                  , service = Artifacts.Type.Rosetta
                  , network = spec.network
                  , deb_profile = profile
                  , deb_repo = DebianRepo.Type.Local
                  , deb_codename = codename
                  , deb_suffix = Some "hardfork"
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
                   (RunInToolchain.runInToolchain
                        ([]: List Text)
                        "./buildkite/scripts/cache/manager.sh read hardfork/legacy legacy-ledgers ")
                        #
                    [ Cmd.run
                        "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                      codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                    , Cmd.runInDocker
                        Cmd.Docker::{ image = image }
                        "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=config.json mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                          spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputed_block_prefix_arg} --reference-data-dir ./legacy-ledgers "
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
      ->  \(use_artifacts_from_buildkite_build: Optional Text)
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
              , use_artifacts_from_buildkite_build = use_artifacts_from_buildkite_build
              }
          ).pipeline

in  { generate_hardfork_package = generate_hardfork_package }
