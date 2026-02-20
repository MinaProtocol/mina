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

let Extensions = ../Lib/Extensions.dhall

let List/map = Prelude.List.map

let DebianArchPair =
      { DebVersion : DebianVersions.DebVersion, Arch : Arch.Type }

let Spec =
      { Type =
          { codenames : List DebianArchPair
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
          { codenames =
            [ { DebVersion = DebianVersions.DebVersion.Bullseye
              , Arch = Arch.Type.Amd64
              }
            ]
          , network = Network.Type.TestnetGeneric
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
      ->  \ ( codename
            : { DebVersion : DebianVersions.DebVersion, Arch : Arch.Type }
            )
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
                      codename.DebVersion
                      codename.Arch
                      [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                      "./buildkite/scripts/hardfork/release/generate-fork-config-and-ledger-tarballs-using-legacy-app.sh --network ${Network.lowerName
                                                                                                                                       spec.network} --version 3.2.0-f77c8c9  --codename ${DebianVersions.lowerName
                                                                                                                                                                                             codename.DebVersion} --config-json-gz-url ${spec.config_json_gz_url} ${cacheArg}"
                , label =
                    "Generate hardfork reference tarballs for ${DebianVersions.lowerName
                                                                  codename.DebVersion}"
                , key = key
                , depends_on = depends_on
                , target = Size.Large
                }

let generateTarballsCommand =
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  \(codenames : List DebianArchPair)
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
                      codename.DebVersion
                      codename.Arch
                      [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                      (     "./buildkite/scripts/hardfork/release/generate-fork-config-and-ledger-tarballs.sh "
                        ++  "--network ${Network.lowerName spec.network} "
                        ++  "--config-url ${spec.config_json_gz_url} "
                        ++  "--codename ${DebianVersions.lowerName
                                            codename.DebVersion} "
                        ++  "${cacheArg}"
                      )
                , label =
                    "Generate hardfork tarballs for ${DebianVersions.lowerName
                                                        codename.DebVersion}"
                , key = key
                , depends_on = depends_on
                , target = Size.Large
                }

let generateDockerForCodename =
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  \(pipelineName : Text)
      ->  let profile = Profiles.fromNetwork spec.network

          let lowerNameCodename = DebianVersions.lowerName codename.DebVersion

          let buildHfDebian = "build-hf-debian"

          let dependsOnBuildHfDebian =
                [ { name = pipelineName, key = buildHfDebian } ]

          let dockerDaemonSpec =
                DockerImage.ReleaseSpec::{
                , deps = dependsOnBuildHfDebian
                , service = Artifacts.Type.Daemon
                , network = spec.network
                , deb_codename = codename.DebVersion
                , deb_profile = profile
                , deb_repo = DebianRepo.Type.Local
                , step_key_suffix =
                    "-${DebianVersions.lowerName
                          codename.DebVersion}-docker-image"
                , size = spec.size
                }

          let buildOrGetArtifacts =
                merge
                  { Some = \(build : Text) -> [] : List Command.Type
                  , None =
                    [ MinaArtifact.buildArtifacts
                        MinaArtifact.MinaBuildSpec::{
                        , artifacts =
                          [ Artifacts.Type.LogProc
                          , Artifacts.Type.Daemon
                          , Artifacts.Type.DaemonConfig
                          , Artifacts.Type.Archive
                          , Artifacts.Type.Rosetta
                          , Artifacts.Type.ZkappTestTransaction
                          ]
                        , debVersion = codename.DebVersion
                        , profile = profile
                        , network = spec.network
                        , prefix = pipelineName
                        , suffix = Some "-${lowerNameCodename}"
                        }
                    ]
                  }
                  spec.use_artifacts_from_buildkite_build

          in    buildOrGetArtifacts
              # [ DockerImage.generateStep dockerDaemonSpec
                , DockerImage.generateStep
                    DockerImage.ReleaseSpec::{
                    , deps = dependsOnBuildHfDebian
                    , service = Artifacts.Type.Archive
                    , network = spec.network
                    , deb_codename = codename.DebVersion
                    , deb_profile = profile
                    , deb_repo = DebianRepo.Type.Local
                    , deb_version = spec.version
                    , size = spec.size
                    , step_key_suffix =
                        "-${DebianVersions.lowerName
                              codename.DebVersion}-docker-image"
                    }
                , DockerImage.generateStep
                    DockerImage.ReleaseSpec::{
                    , deps = dependsOnBuildHfDebian
                    , service = Artifacts.Type.Rosetta
                    , network = spec.network
                    , deb_profile = profile
                    , deb_repo = DebianRepo.Type.Local
                    , deb_codename = codename.DebVersion
                    , deb_version = spec.version
                    , size = spec.size
                    , step_key_suffix =
                        "-${DebianVersions.lowerName
                              codename.DebVersion}-docker-image"
                    }
                ]

let generateHfRelatedStepsForCodename =
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  \(codenames : List DebianArchPair)
      ->  \(pipelineName : Text)
      ->  let image =
                Artifacts.fullDockerTag
                  Artifacts.Tag::{
                  , remove_profile_from_name = True
                  , network = spec.network
                  }

          let profile = Profiles.fromNetwork spec.network

          let lowerNameCodename = DebianVersions.lowerName codename.DebVersion

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
                , deb_codename = codename.DebVersion
                , deb_profile = profile
                , deb_repo = DebianRepo.Type.Local
                , step_key_suffix =
                    "-${DebianVersions.lowerName
                          codename.DebVersion}-docker-image"
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

          let dependsOnArtifactsOrEmpty =
                merge
                  { Some = \(_ : Text) -> [] : List Command.TaggedKey.Type
                  , None = dependsOnArtifacts
                  }
                  spec.use_artifacts_from_buildkite_build

          let generateTarballs =
                [ generateTarballsCommand
                    spec
                    codename
                    codenames
                    tarballGenKey
                    dependsOnArtifactsOrEmpty
                , generateReferenceTarballsCommand
                    spec
                    codename
                    referencesTarballStepKey
                    dependsOnArtifactsOrEmpty
                ]

          let cached_tarball_ledgers =
                "--cached-hardfork-data /var/storagebox/\\\${BUILDKITE_BUILD_ID}/hardfork/ "

          let cached_reference_ledgers =
                "--reference-data-dir /var/storagebox/\\\${BUILDKITE_BUILD_ID}/hardfork/legacy "

          let debianCodenames =
                List/map
                  DebianArchPair
                  Text
                  (     \(c : DebianArchPair)
                    ->  DebianVersions.lowerName c.DebVersion
                  )
                  codenames

          let debianCodenamesList = Extensions.join "," debianCodenames

          in    generateTarballs
              # [ Command.build
                    Command.Config::{
                    , commands =
                        Toolchain.select
                          Toolchain.SelectionMode.ByDebianAndArch
                          codename.DebVersion
                          codename.Arch
                          [ "NETWORK_NAME=${Network.lowerName spec.network}"
                          , "MINA_DEB_CODENAME=${lowerNameCodename}"
                          ]
                          (     "mkdir -p _build && ./buildkite/scripts/cache/manager.sh read hardfork /workdir && RUNTIME_CONFIG_JSON=/workdir/hardfork/new_config.json LEDGER_TARBALLS='/workdir/hardfork/ledgers/*.tar.gz' ./buildkite/scripts/debian/build.sh --codenames ${debianCodenamesList} --arch all daemon_${Network.lowerName
                                                                                                                                                                                                                                                                                                                           spec.network}_hardfork_config"
                            ++  merge
                                  { Some =
                                          \(cached_build_id : Text)
                                      ->      "&& ./buildkite/scripts/release/manager.sh persist "
                                          ++  " --backend local --artifacts mina-logproc,mina-${Network.lowerName
                                                                                                  spec.network},mina-archive-${Network.lowerName
                                                                                                                                 spec.network},mina-rosetta-${Network.lowerName
                                                                                                                                                                spec.network},mina-zkapp-test-transaction "
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
                , Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.run
                          "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                        codename.DebVersion} && source ./buildkite/scripts/export-git-env-vars.sh"
                      , Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed 's/B62qiburnzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmp7r7UN6X/B62qrTP88hjyU3hq6QNvFafX8sgHrsAW6v7tt5twrcugJM4bBV2eu9k/g' -i config.json && ! (FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                                                                                                                                                                  spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                                                                                                                                                                                  spec.network} --fork-config config.json --working-dir /workdir/verification --checks config)"
                      ]
                    , label =
                        "Assert corrupted packaged artifacts are unverifiable"
                    , key =
                        "assert-unverify-corrupted-packaged-artifacts-${DebianVersions.lowerName
                                                                          codename.DebVersion}"
                    , target = Size.XLarge
                    , depends_on = dependsOnTest
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.run
                          "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                        codename.DebVersion} && source ./buildkite/scripts/export-git-env-vars.sh"
                      , Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                   spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                                   spec.network} --fork-config config.json  --cached-hardfork-data /workdir/hardfork --working-dir /workdir/verification ${precomputed_block_prefix_arg} ${cached_tarball_ledgers} ${cached_reference_ledgers} --checks config"
                      ]
                    , label = "Verify packaged artifacts: Config check"
                    , key =
                        "verify-packaged-artifacts-config-${DebianVersions.lowerName
                                                              codename.DebVersion}"
                    , target = Size.Small
                    , depends_on = dependsOnTest
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                          Toolchain.select
                            Toolchain.SelectionMode.ByDebianAndArch
                            codename.DebVersion
                            codename.Arch
                            ([] : List Text)
                            "./buildkite/scripts/cache/manager.sh read hardfork . && ls -al ./hardfork"
                        # [ Cmd.run
                              "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                            codename.DebVersion} && source ./buildkite/scripts/export-git-env-vars.sh"
                          , Cmd.runInDocker
                              Cmd.Docker::{ image = image }
                              "curl -sL ${spec.config_json_gz_url} | gunzip > config.json && MINA_LOG_LEVEL=Spam FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                            spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                                            spec.network} --fork-config config.json --cached-hardfork-data /workdir/hardfork --working-dir /workdir/hardfork ${precomputed_block_prefix_arg} ${cached_reference_ledgers} --checks ledgers  ${cached_tarball_ledgers}"
                          ]
                    , label = "Verify packaged artifacts: Ledgers check"
                    , key =
                        "verify-packaged-artifacts-ledgers-${DebianVersions.lowerName
                                                               codename.DebVersion}"
                    , target = Size.XLarge
                    , depends_on = dependsOnTest
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.run
                          "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                        codename.DebVersion} && source ./buildkite/scripts/export-git-env-vars.sh"
                      , Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl -sL ${spec.config_json_gz_url} | gunzip > config.json && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                    spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                    spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputed_block_prefix_arg} --checks tarballs ${cached_tarball_ledgers} ${cached_reference_ledgers}"
                      ]
                    , label = "Verify packaged artifacts: Tarballs check"
                    , key =
                        "verify-packaged-artifacts-tarballs-${DebianVersions.lowerName
                                                                codename.DebVersion}"
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
                          if Prelude.List.null DebianArchPair spec.codenames

                    then  [] : List Command.Type

                    else  let first =
                                Prelude.List.head DebianArchPair spec.codenames

                          in    merge
                                  { Some =
                                          \(codename : DebianArchPair)
                                      ->  generateHfRelatedStepsForCodename
                                            spec
                                            codename
                                            spec.codenames
                                            pipelineName
                                  , None = [] : List Command.Type
                                  }
                                  first
                              # List/concatMap
                                  DebianArchPair
                                  Command.Type
                                  (     \(codename : DebianArchPair)
                                    ->  generateDockerForCodename
                                          spec
                                          codename
                                          pipelineName
                                  )
                                  spec.codenames
                }

let generate_hardfork_package =
          \(codenames : List DebianArchPair)
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
