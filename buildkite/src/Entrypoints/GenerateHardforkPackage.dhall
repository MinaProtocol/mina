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

let Toolchain = ../Constants/Toolchain.dhall

let Arch = ../Constants/Arch.dhall

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

let generateReferenceTarballsCommand =
          \(spec : Spec.Type)
      ->  \(codename : DebianVersions.DebVersion)
      ->  \(key : Text)
      ->  \(depends_on : List Command.TaggedKey.Type)
      ->  let cacheArg =
                merge
                  { Some =
                      \(build : Text) -> "--cached-buildkite-build-id " ++ build
                  , None = ""
                  }
                  spec.use_artifacts_from_buildkite_build

          in  Command.build
                Command.Config::{
                , commands =
                    Toolchain.select
                      Toolchain.SelectionMode.ByDebianAndArch
                      codename
                      Arch.Type.Amd64
                      [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                      (     "./buildkite/scripts/hardfork/generate-reference-tarballs.sh "
                        ++  "--network ${Network.lowerName spec.network} "
                        ++  "--config-url ${spec.config_json_gz_url} "
                        ++  "--codename ${DebianVersions.lowerName
                                            codename} ${cacheArg}"
                      )
                , label =
                    "Generate hardfork reference tarballs for ${DebianVersions.lowerName
                                                                  codename}"
                , key = key
                , depends_on = depends_on
                , target = Size.Large
                }

let generateTarballsCommand =
          \(spec : Spec.Type)
      ->  \(codename : DebianVersions.DebVersion)
      ->  \(key : Text)
      ->  \(depends_on : List Command.TaggedKey.Type)
      ->  let cacheArg =
                merge
                  { Some =
                      \(build : Text) -> "--cached-buildkite-build-id " ++ build
                  , None = ""
                  }
                  spec.use_artifacts_from_buildkite_build

          in  Command.build
                Command.Config::{
                , commands =
                    Toolchain.select
                      Toolchain.SelectionMode.ByDebianAndArch
                      codename
                      Arch.Type.Amd64
                      [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                      (     "./buildkite/scripts/hardfork/generate-tarballs.sh "
                        ++  "--network ${Network.lowerName spec.network} "
                        ++  "--config-url ${spec.config_json_gz_url} "
                        ++  "--codename ${DebianVersions.lowerName
                                            codename} ${cacheArg}"
                      )
                , label =
                    "Generate hardfork tarballs for ${DebianVersions.lowerName
                                                        codename}"
                , key = key
                , depends_on = depends_on
                , target = Size.Large
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

          let artifactsGenKey = "build-deb-pkg-${lowerNameCodename}"

          let tarballGenKey = "generate-hardfork-tarballs-${lowerNameCodename}"

          let buildHfDebian = "build-hf-debian-${lowerNameCodename}"

          let dependsOnTarballs =
                [ { name = pipelineName, key = tarballGenKey } ]

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
                , deb_version = spec.version
                , deb_suffix = Some "hardfork"
                , step_key_suffix = "-${lowerNameCodename}-docker-image"
                , size = spec.size
                }

          let dockerDaemonStep = DockerImage.stepKey dockerDaemonSpec

          let referencesTarballStepKey =
                "generate-reference-tarballs-" ++ lowerNameCodename

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
                      ->  [ generateTarballsCommand
                              spec
                              codename
                              tarballGenKey
                              ([] : List Command.TaggedKey.Type)
                          , generateReferenceTarballsCommand
                              spec
                              codename
                              referencesTarballStepKey
                              ([] : List Command.TaggedKey.Type)
                          ]
                  , None =
                    [ MinaArtifact.buildArtifacts
                        MinaArtifact.MinaBuildSpec::{
                        , artifacts =
                          [ Artifacts.Type.LogProc
                          , Artifacts.Type.Daemon
                          , Artifacts.Type.Archive
                          , Artifacts.Type.Rosetta
                          , Artifacts.Type.ZkappTestTransaction
                          ]
                        , debVersion = codename
                        , profile = profile
                        , network = spec.network
                        , prefix = pipelineName
                        , suffix = Some "-${lowerNameCodename}"
                        }
                    , generateTarballsCommand
                        spec
                        codename
                        tarballGenKey
                        dependsOnArtifacts
                    , generateReferenceTarballsCommand
                        spec
                        codename
                        referencesTarballStepKey
                        dependsOnArtifacts
                    ]
                  }
                  spec.use_artifacts_from_buildkite_build

          let useArtifactsEnvVar =
                merge
                  { Some =
                          \(build : Text)
                      ->  [ "CACHED_BUILDKITE_BUILD_ID=${build} " ]
                  , None = [] : List Text
                  }
                  spec.use_artifacts_from_buildkite_build

          let cached_tarball_ledgers =
                merge
                  { Some = \(build : Text) -> "--cached-hardfork-data ${build} "
                  , None = ""
                  }
                  spec.use_artifacts_from_buildkite_build

          in    buildOrGetArtifacts
              # [ Command.build
                    Command.Config::{
                    , commands =
                        Toolchain.select
                          Toolchain.SelectionMode.ByDebianAndArch
                          codename
                          Arch.Type.Amd64
                          (   [ "NETWORK_NAME=${Network.lowerName spec.network}"
                              , "CONFIG_JSON_GZ_URL=${spec.config_json_gz_url}"
                              , "CODENAME=${lowerNameCodename}"
                              ]
                            # useArtifactsEnvVar
                          )
                          (     "./buildkite/scripts/hardfork/prepare-hf-debian.sh "
                            ++  merge
                                  { Some =
                                          \(cached_build_id : Text)
                                      ->      "&& ./buildkite/scripts/release/manager.sh persist "
                                          ++  " --backend local --artifacts mina-logproc,mina-archive-${Network.lowerName
                                                                                                          spec.network},mina-rosetta-${Network.lowerName
                                                                                                                                         spec.network} "
                                          ++  " --buildkite-build-id ${cached_build_id}"
                                          ++  " --codename ${lowerNameCodename} "
                                          ++  " --target \\\${BUILDKITE_BUILD_ID} "
                                  , None = ""
                                  }
                                  spec.use_artifacts_from_buildkite_build
                          )
                    , label =
                        "Create hardfork packages for ${lowerNameCodename}"
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
                    , deb_version = spec.version
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
                    , deb_version = spec.version
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
                          Toolchain.select
                            Toolchain.SelectionMode.ByDebianAndArch
                            codename
                            Arch.Type.Amd64
                            ([] : List Text)
                            "./buildkite/scripts/cache/manager.sh read hardfork . && ls -al ./hardfork"
                        # [ Cmd.run
                              "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                            codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                          , Cmd.runInDocker
                              Cmd.Docker::{ image = image }
                              "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                       spec.network}.json mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                         spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputed_block_prefix_arg} --reference-data-dir /workdir/hardfork/legacy --checks config"
                          ]
                    , label = "Verify packaged artifacts: Config check"
                    , key =
                        "verify-packaged-artifacts-config-${DebianVersions.lowerName
                                                              codename}"
                    , target = Size.Small
                    , depends_on = dependsOnTest
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                          Toolchain.select
                            Toolchain.SelectionMode.ByDebianAndArch
                            codename
                            Arch.Type.Amd64
                            ([] : List Text)
                            "./buildkite/scripts/cache/manager.sh read hardfork . && ls -al ./hardfork"
                        # [ Cmd.run
                              "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                            codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                          , Cmd.runInDocker
                              Cmd.Docker::{ image = image }
                              "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                       spec.network}.json mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                         spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputed_block_prefix_arg} --reference-data-dir /workdir/hardfork/legacy --checks ledgers  ${cached_tarball_ledgers}"
                          ]
                    , label = "Verify packaged artifacts: Ledgers check"
                    , key =
                        "verify-packaged-artifacts-ledgers-${DebianVersions.lowerName
                                                               codename}"
                    , target = Size.XLarge
                    , depends_on = dependsOnTest
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                          Toolchain.select
                            Toolchain.SelectionMode.ByDebianAndArch
                            codename
                            Arch.Type.Amd64
                            ([] : List Text)
                            "./buildkite/scripts/cache/manager.sh read hardfork ."
                        # [ Cmd.run
                              "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                            codename} && source ./buildkite/scripts/export-git-env-vars.sh"
                          , Cmd.runInDocker
                              Cmd.Docker::{ image = image }
                              "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=config.json mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputed_block_prefix_arg} --reference-data-dir /workdir/hardfork/legacy --checks tarballs"
                          ]
                    , label = "Verify packaged artifacts: Tarballs check"
                    , key =
                        "verify-packaged-artifacts-tarballs-${DebianVersions.lowerName
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
      ->  \(use_artifacts_from_buildkite_build : Optional Text)
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
              , use_artifacts_from_buildkite_build =
                  use_artifacts_from_buildkite_build
              }
          ).pipeline

in  { generate_hardfork_package = generate_hardfork_package }
