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

let DockerPublish = ../Constants/Docker/Publish.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Docker = ../Constants/Docker/Package.dhall

let Artifact = ../Constants/Artifact/Artifacts.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let Toolchain = ../Constants/Toolchain.dhall

let Arch = ../Constants/Arch.dhall

let Extensions = ../Lib/Extensions.dhall

let List/map = Prelude.List.map

let DebianArchPair =
      { DebVersion : DebianVersions.DebVersion, Arch : Arch.Type }

let defaultMinaArtifactSpec = MinaArtifact.PackagingSpec::{=}

let dockerRepo =
    -- Always the internal euro registry. Every image is pushed there by this
    -- build and also written to the build's cache, so a hardfork candidate
    -- can be run from the registry, which needs credentials, without reaching
    -- a user. The fork-day publish (Jobs/Release/PublishDockers.dhall) takes
    -- the images from the cache and retags them for docker.io itself, so the
    -- registry named here is never the public one.
      DockerRepo.Type.InternalEurope

let buildCacheDir = MinaArtifact.ownBuildCacheDir

let debianChannel =
    -- The channel the packages are built for, so their Suite matches the
    -- channel the publish pipeline is pointed at (MINA_RELEASE_CHANNEL, the
    -- same variable). Unstable unless the pipeline says otherwise.
      DebianChannel.effective DebianChannel.Type.Unstable

let hardforkDockerSpec =
    -- The image step as the hardfork pipeline wants it: tagged for and pushed
    -- to the euro registry, and written to this build's cache for the
    -- fork-day publish. The layered bases (generic -> profiled -> configured)
    -- come from the same cache, except when the generic images are taken
    -- from a version in the registry: then there is no cached base, and
    -- build.sh pulls it.
          \(fromRegistry : Bool)
      ->  \(docker : DockerImage.ReleaseSpec.Type)
      ->      docker
          //  { docker_repo = dockerRepo
              , docker_publish = DockerPublish.Type.Enabled
              , deb_release = debianChannel
              , build_cache_dir = Some buildCacheDir
              , base_cache_dir =
                  if fromRegistry then None Text else Some buildCacheDir
              }

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
          , use_generic_dockers_from_version : Optional Text
          , hardfork_config_url : Optional Text
          , size : Size
          , deb_legacy_version : Text
          , deb_legacy_githash_config : Text
          }
      , default =
          { codenames =
            [ { DebVersion = DebianVersions.DebVersion.Bookworm
              , Arch = Arch.Type.Amd64
              }
            ]
          , network = Network.Type.Devnet
          , genesis_timestamp = Some "2024-04-07T11:45:00Z"
          , config_json_gz_url =
              "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz"
          , suffix = ""
          , version = "\\\${MINA_DEB_VERSION}"
          , precomputed_block_prefix = None Text
          , use_artifacts_from_buildkite_build = None Text
          , use_generic_dockers_from_version = None Text
          , hardfork_config_url = None Text
          , size = Size.XLarge
          , deb_legacy_version = defaultMinaArtifactSpec.deb_legacy_version
          , deb_legacy_githash_config =
              defaultMinaArtifactSpec.deb_legacy_githash_config
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
                      Toolchain.Spec::{
                      , debVersion = codename.DebVersion
                      , arch = codename.Arch
                      , submodules = True
                      }
                      [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                      "./buildkite/scripts/hardfork/release/generate-fork-config-and-ledger-tarballs-using-legacy-app.sh --network ${Network.lowerName
                                                                                                                                       spec.network} --version ${spec.deb_legacy_version}  --codename ${DebianVersions.lowerName
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

          let genesis_timestamp_env =
                merge
                  { Some = \(ts : Text) -> [ "GENESIS_TIMESTAMP=" ++ ts ]
                  , None = [] : List Text
                  }
                  spec.genesis_timestamp

          in  Command.build
                Command.Config::{
                , commands =
                    Toolchain.select
                      Toolchain.Spec::{
                      , debVersion = codename.DebVersion
                      , arch = codename.Arch
                      , submodules = True
                      }
                      (   [ "AWS_ACCESS_KEY_ID"
                          , "AWS_SECRET_ACCESS_KEY"
                          , "GENESIS_TIMESTAMP"
                          ]
                        # genesis_timestamp_env
                      )
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

          let daemonGeneric =
                DockerImage.ReleaseSpec::{
                , deps = dependsOnBuildHfDebian
                , service = Docker.Type.DaemonGeneric
                , network = spec.network
                , deb_codename = codename.DebVersion
                , deb_profile = profile
                , deb_legacy_version = spec.deb_legacy_version
                , docker_target = Some "mina-daemon-prefork-genesis"
                , size = spec.size
                , deb_version = spec.version
                , generic = True
                , step_key_suffix =
                    "-${DebianVersions.lowerName
                          codename.DebVersion}-docker-image"
                }

          let dependsOnDaemonGeneric =
                [ { name = pipelineName
                  , key = DockerImage.stepKey daemonGeneric
                  }
                ]

          let daemonProfiled =
                DockerImage.ReleaseSpec::{
                , deps = dependsOnBuildHfDebian # dependsOnDaemonGeneric
                , service = Docker.Type.DaemonProfiled { profile = profile }
                , network = spec.network
                , deb_codename = codename.DebVersion
                , deb_profile = profile
                , deb_install_mode = DockerImage.DebianInstallMode.DownloadOnly
                , deb_legacy_version = spec.deb_legacy_version
                , size = spec.size
                , deb_version = spec.version
                , step_key_suffix =
                    "-${DebianVersions.lowerName
                          codename.DebVersion}-docker-image"
                }

          let dependsOnDaemonProfiled =
                [ { name = pipelineName
                  , key = DockerImage.stepKey daemonProfiled
                  }
                ]

          let rosettaGeneric =
                DockerImage.ReleaseSpec::{
                , deps = dependsOnBuildHfDebian
                , service = Docker.Type.RosettaGeneric
                , network = spec.network
                , deb_codename = codename.DebVersion
                , deb_profile = profile
                , deb_legacy_version = spec.deb_legacy_version
                , size = spec.size
                , deb_version = spec.version
                , generic = True
                , step_key_suffix =
                    "-${DebianVersions.lowerName
                          codename.DebVersion}-docker-image"
                }

          let dependsOnRosettaGeneric =
                [ { name = pipelineName
                  , key = DockerImage.stepKey rosettaGeneric
                  }
                ]

          let persistArtifacts =
                "mina-logproc mina-generic mina-archive-generic mina-rosetta-generic mina-${Profiles.lowerName
                                                                                              profile}-profile mina-${Profiles.lowerName
                                                                                                                        profile}-generic mina-${Network.lowerName
                                                                                                                                                  spec.network} mina-archive-${Network.lowerName
                                                                                                                                                                                 spec.network} mina-rosetta-${Network.lowerName
                                                                                                                                                                                                                spec.network} mina-tx-tools mina-daemon-storage-toolbox"

          let buildOrGetArtifacts =
                merge
                  { Some =
                          \(cached_build_id : Text)
                      ->  [ Command.build
                              Command.Config::{
                              , commands =
                                  Toolchain.select
                                    Toolchain.Spec::{
                                    , debVersion = codename.DebVersion
                                    , arch = codename.Arch
                                    , submodules = True
                                    }
                                    [ "FORCE_DOCKER_OVERWRITE" ]
                                    (     "tmp=\$(mktemp -d) && "
                                      ++  "for a in ${persistArtifacts}; do buildkite-cache-manager read --root ${cached_build_id} \"debians/${lowerNameCodename}/\${a}_*_amd64.deb\" \"\$tmp\"; done && "
                                      ++  "buildkite-cache-manager write \"\$tmp\"/* debians/${lowerNameCodename}/"
                                    )
                              , label =
                                  "Download cached packages for ${lowerNameCodename}"
                              , key =
                                  "download-cached-artifacts-${lowerNameCodename}"
                              , target = Size.Multi
                              }
                          ]
                  , None =
                    [ MinaArtifact.buildArtifacts
                        MinaArtifact.PackagingSpec::{
                        , artifacts =
                          [ Artifact.Type.LogProc
                          , Artifact.Type.DaemonGeneric
                          , Artifact.Type.ArchiveGeneric
                          , Artifact.Type.RosettaGeneric
                          , Artifact.Type.Daemon { network = spec.network }
                          , Artifact.Type.DaemonProfiled { profile = profile }
                          , Artifact.Type.Archive { network = spec.network }
                          , Artifact.Type.Rosetta { network = spec.network }
                          , Artifact.Type.TxTools
                          , Artifact.Type.DaemonStorageToolbox
                          ]
                        , debVersion = codename.DebVersion
                        , prefix = pipelineName
                        , suffix = Some "-${lowerNameCodename}"
                        , deb_legacy_githash_config =
                            spec.deb_legacy_githash_config
                        }
                    ]
                  }
                  spec.use_artifacts_from_buildkite_build

          let dockerSpecs =
                merge
                  { Some =
                          \(version : Text)
                      ->  [ DockerImage.ReleaseSpec::{
                            , deps = dependsOnBuildHfDebian
                            , service =
                                Docker.Type.Daemon { network = spec.network }
                            , network = spec.network
                            , deb_codename = codename.DebVersion
                            , deb_profile = profile
                            , deb_install_mode =
                                DockerImage.DebianInstallMode.DownloadOnly
                            , deb_legacy_version = spec.deb_legacy_version
                            , size = spec.size
                            , verify = True
                            , version =
                                "${version}-${DebianVersions.lowerName
                                                codename.DebVersion}"
                            , deb_version = spec.version
                            , step_key_suffix =
                                "-${DebianVersions.lowerName
                                      codename.DebVersion}-docker-image"
                            }
                          , DockerImage.ReleaseSpec::{
                            , deps = dependsOnBuildHfDebian
                            , service =
                                Docker.Type.Rosetta { network = spec.network }
                            , network = spec.network
                            , deb_codename = codename.DebVersion
                            , deb_profile = profile
                            , deb_install_mode =
                                DockerImage.DebianInstallMode.DownloadOnly
                            , deb_legacy_version = spec.deb_legacy_version
                            , image_name = Some
                                ( Docker.dockerName
                                    ( Docker.Type.Rosetta
                                        { network = spec.network }
                                    )
                                )
                            , size = spec.size
                            , verify = True
                            , version =
                                "${version}-${DebianVersions.lowerName
                                                codename.DebVersion}"
                            , deb_version = spec.version
                            , step_key_suffix =
                                "-${DebianVersions.lowerName
                                      codename.DebVersion}-docker-image"
                            }
                          , DockerImage.ReleaseSpec::{
                            , deps = dependsOnBuildHfDebian
                            , service =
                                Docker.Type.Archive { network = spec.network }
                            , network = spec.network
                            , deb_codename = codename.DebVersion
                            , deb_install_mode =
                                DockerImage.DebianInstallMode.DownloadOnly
                            , deb_profile = profile
                            , deb_legacy_version = spec.deb_legacy_version
                            , size = spec.size
                            , deb_version = spec.version
                            , step_key_suffix =
                                "-${DebianVersions.lowerName
                                      codename.DebVersion}-docker-image"
                            }
                          ]
                  , None =
                    [ daemonGeneric
                    , daemonProfiled
                    , DockerImage.ReleaseSpec::{
                      , deps = dependsOnBuildHfDebian # dependsOnDaemonProfiled
                      , service = Docker.Type.Daemon { network = spec.network }
                      , network = spec.network
                      , deb_codename = codename.DebVersion
                      , deb_profile = profile
                      , deb_install_mode =
                          DockerImage.DebianInstallMode.DownloadOnly
                      , deb_legacy_version = spec.deb_legacy_version
                      , size = spec.size
                      , verify = True
                      , deb_version = spec.version
                      , step_key_suffix =
                          "-${DebianVersions.lowerName
                                codename.DebVersion}-docker-image"
                      }
                    , DockerImage.ReleaseSpec::{
                      , deps = dependsOnBuildHfDebian
                      , service = Docker.Type.Archive { network = spec.network }
                      , network = spec.network
                      , deb_codename = codename.DebVersion
                      , deb_profile = profile
                      , deb_legacy_version = spec.deb_legacy_version
                      , size = spec.size
                      , deb_version = spec.version
                      , step_key_suffix =
                          "-${DebianVersions.lowerName
                                codename.DebVersion}-docker-image"
                      }
                    , rosettaGeneric
                    , DockerImage.ReleaseSpec::{
                      , deps = dependsOnBuildHfDebian # dependsOnRosettaGeneric
                      , service = Docker.Type.Rosetta { network = spec.network }
                      , network = spec.network
                      , deb_codename = codename.DebVersion
                      , deb_profile = profile
                      , deb_install_mode =
                          DockerImage.DebianInstallMode.DownloadOnly
                      , deb_legacy_version = spec.deb_legacy_version
                      , image_name = Some
                          ( Docker.dockerName
                              (Docker.Type.Rosetta { network = spec.network })
                          )
                      , size = spec.size
                      , verify = True
                      , deb_version = spec.version
                      , step_key_suffix =
                          "-${DebianVersions.lowerName
                                codename.DebVersion}-docker-image"
                      }
                    ]
                  }
                  spec.use_generic_dockers_from_version

          let fromRegistry =
                merge
                  { Some = \(_ : Text) -> True, None = False }
                  spec.use_generic_dockers_from_version

          in    buildOrGetArtifacts
              # List/map
                  DockerImage.ReleaseSpec.Type
                  Command.Type
                  (     \(docker : DockerImage.ReleaseSpec.Type)
                    ->  DockerImage.generateStep
                          (hardforkDockerSpec fromRegistry docker)
                  )
                  dockerSpecs

let fetchHardforkConfigCommand =
    -- The ready config, which the mina-state-dump job uploads, written to the
    -- cache in the layout the packaging reads. It takes the key of the
    -- generation step, so the packaging waits for it as for a generated
    -- config, and it needs no package of this build. The ledgers are not
    -- rebuilt from the dump: the verification compares the package with the
    -- fork block and the dump directly.
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  \(url : Text)
      ->  \(key : Text)
      ->  let genesis_timestamp_env =
                merge
                  { Some = \(ts : Text) -> [ "GENESIS_TIMESTAMP=" ++ ts ]
                  , None = [] : List Text
                  }
                  spec.genesis_timestamp

          in  Command.build
                Command.Config::{
                , commands =
                    Toolchain.select
                      Toolchain.Spec::{
                      , debVersion = codename.DebVersion
                      , arch = codename.Arch
                      , submodules = True
                      }
                      (   [ "AWS_ACCESS_KEY_ID"
                          , "AWS_SECRET_ACCESS_KEY"
                          , "GENESIS_TIMESTAMP"
                          ]
                        # genesis_timestamp_env
                      )
                      (     "./buildkite/scripts/hardfork/release/fetch-hardfork-config.sh "
                        ++  "--network ${Network.lowerName spec.network} "
                        ++  "--url ${url} "
                        ++  "--config-json-gz-url ${spec.config_json_gz_url}"
                      )
                , label =
                    "Fetch the hardfork config for ${DebianVersions.lowerName
                                                       codename.DebVersion}"
                , key = key
                , target = Size.Small
                }

let referenceLedgersKey =
    -- The step that writes the reference ledgers the verification reads: the
    -- fetch step with a ready config, the reference generation otherwise.
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  let lowerNameCodename = DebianVersions.lowerName codename.DebVersion

          in  merge
                { Some =
                        \(_ : Text)
                    ->  "generate-hardfork-tarballs-${lowerNameCodename}"
                , None = "generate-reference-tarballs-${lowerNameCodename}"
                }
                spec.hardfork_config_url

let daemonImage =
    -- The configured daemon image of one codename, and how to load it. The
    -- verification takes it from this build's cache, where its build step
    -- wrote it, so it runs the image that was built here.
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  let imageTag =
                Docker.Tag::{
                , remove_profile_from_name = True
                , network = spec.network
                , version =
                    merge
                      { Some =
                              \(v : Text)
                          ->  "${v}-${DebianVersions.lowerName
                                        codename.DebVersion}"
                      , None = "\\\${MINA_DOCKER_TAG}"
                      }
                      spec.use_generic_dockers_from_version
                }

          let image =
                "${DockerRepo.show
                     dockerRepo}/${Docker.dockerName
                                     imageTag.package}:${Docker.dockerTag
                                                           imageTag}"

          in  { image = image
              , load =
                  Cmd.run
                    "CACHE_ROOT=${buildCacheDir} ./buildkite/scripts/docker/load_from_cache.sh ${image}"
              }

let precomputedBlockArg =
          \(flag : Text)
      ->  \(spec : Spec.Type)
      ->  merge
            { Some = \(prefix : Text) -> "${flag} ${prefix}", None = "" }
            spec.precomputed_block_prefix

let preflightKey = "preflight-state-dump"

let preflightCommand =
    -- The dump is checked before anything is built from it, beside the build
    -- and not ahead of it: no deb or image waits for this step. The reference
    -- tarballs do, and the verification with them, so a bad dump stops those
    -- within seconds and the builds carry on.
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  Command.build
            Command.Config::{
            , commands =
                Toolchain.select
                  Toolchain.Spec::{
                  , debVersion = codename.DebVersion
                  , arch = codename.Arch
                  }
                  ([] : List Text)
                  "./scripts/hardfork/release/check-fork-dump.py --network ${Network.lowerName
                                                                               spec.network} --config-url ${spec.config_json_gz_url} ${precomputedBlockArg
                                                                                                                                         "--block-prefix"
                                                                                                                                         spec}"
            , label = "Preflight: check the state dump"
            , key = preflightKey
            , target = Size.Small
            }

let verifyImageCommand =
    -- The full verification runs for the first codename. Every other codename
    -- has its own image, with its own binary and packages, so it gets the
    -- checks that read the image. amd64 only: the verification runs on amd64
    -- agents.
          \(spec : Spec.Type)
      ->  \(pipelineName : Text)
      ->  \(firstCodename : DebianArchPair)
      ->  \(codename : DebianArchPair)
      ->  let daemon = daemonImage spec codename

          let lowerNameCodename = DebianVersions.lowerName codename.DebVersion

          let dockerDaemonSpec =
                DockerImage.ReleaseSpec::{
                , service = Docker.Type.Daemon { network = spec.network }
                , network = spec.network
                , deb_codename = codename.DebVersion
                , deb_profile = Profiles.fromNetwork spec.network
                , deb_legacy_version = spec.deb_legacy_version
                , step_key_suffix = "-${lowerNameCodename}-docker-image"
                , size = spec.size
                }

          in  merge
                { Amd64 =
                  [ Command.build
                      Command.Config::{
                      , commands =
                        [ Cmd.run
                            "export MINA_DEB_CODENAME=${lowerNameCodename} && source ./buildkite/scripts/export-git-env-vars.sh"
                        , daemon.load
                        , Cmd.runInDocker
                            Cmd.Docker::{ image = daemon.image }
                            "curl -sL ${spec.config_json_gz_url} | gunzip > config.json && /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                    spec.network} --fork-config config.json --working-dir /workdir/verification ${precomputedBlockArg
                                                                                                                                                                                                                                                    "--precomputed-block-prefix"
                                                                                                                                                                                                                                                    spec} --reference-data-dir /var/storagebox/\\\${BUILDKITE_BUILD_ID}/hardfork/legacy --checks block,constants,artifacts --prefork-version ${spec.deb_legacy_version}"
                        ]
                      , label =
                          "Verify packaged artifacts: Image check for ${lowerNameCodename}"
                      , key = "verify-packaged-image-${lowerNameCodename}"
                      , target = Size.Small
                      , depends_on =
                        [ { name = pipelineName
                          , key = DockerImage.stepKey dockerDaemonSpec
                          }
                        , { name = pipelineName
                          , key = referenceLedgersKey spec firstCodename
                          }
                        ]
                      }
                  ]
                , Arm64 = [] : List Command.Type
                }
                codename.Arch

let generateHfRelatedStepsForCodename =
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  \(codenames : List DebianArchPair)
      ->  \(pipelineName : Text)
      ->  let daemon = daemonImage spec codename

          let image = daemon.image

          let loadImage = daemon.load

          let profile = Profiles.fromNetwork spec.network

          let lowerNameCodename = DebianVersions.lowerName codename.DebVersion

          let artifactsGenKey = "build-deb-pkg-${lowerNameCodename}"

          let tarballGenKey = "generate-hardfork-tarballs-${lowerNameCodename}"

          let buildHfDebian = "build-hf-debian"

          let dependsOnTarballs =
                [ { name = pipelineName, key = tarballGenKey } ]

          let dependsOnArtifacts =
                [ { name = pipelineName, key = artifactsGenKey } ]

          let service = Docker.Type.Daemon { network = spec.network }

          let dockerDaemonSpec =
                DockerImage.ReleaseSpec::{
                , service = service
                , network = spec.network
                , deb_codename = codename.DebVersion
                , deb_profile = profile
                , deb_legacy_version = spec.deb_legacy_version
                , step_key_suffix =
                    "-${DebianVersions.lowerName
                          codename.DebVersion}-docker-image"
                , size = spec.size
                }

          let dockerDaemonStep = DockerImage.stepKey dockerDaemonSpec

          let referencesTarballStepKey =
                "generate-reference-tarballs-" ++ lowerNameCodename

          let dependsOnTest =
              -- The verification reads the reference ledgers from the cache,
              -- which the reference step writes and the image build does not
              -- wait for.
                [ { name = pipelineName, key = dockerDaemonStep }
                , { name = pipelineName
                  , key = referenceLedgersKey spec codename
                  }
                ]

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
                merge
                  { None =
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
                        (   dependsOnArtifactsOrEmpty
                          # [ { name = pipelineName, key = preflightKey } ]
                        )
                    ]
                  , Some =
                          \(url : Text)
                      ->  [ fetchHardforkConfigCommand
                              spec
                              codename
                              url
                              tarballGenKey
                          ]
                  }
                  spec.hardfork_config_url

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
                          Toolchain.Spec::{
                          , debVersion = codename.DebVersion
                          , arch = codename.Arch
                          , submodules = True
                          }
                          (   [ "NETWORK_NAME=${Network.lowerName spec.network}"
                              , "MINA_DEB_CODENAME=${lowerNameCodename}"
                              , "MINA_DEB_RELEASE=${debianChannel}"
                              ]
                            # DebianVersions.overrideEnvs
                          )
                          "mkdir -p _build && buildkite-cache-manager read hardfork /workdir && RUNTIME_CONFIG_JSON=/workdir/hardfork/new_config.json LEDGER_TARBALLS='/workdir/hardfork/ledgers/*.tar.gz' ./buildkite/scripts/debian/build.sh --codenames ${debianCodenamesList} --arch all daemon_${Network.lowerName
                                                                                                                                                                                                                                                                                                        spec.network}_hardfork_config"
                    , label =
                        "Create hardfork packages for ${lowerNameCodename}"
                    , key = buildHfDebian
                    , target = Size.Large
                    , depends_on = dependsOnTarballs # dependsOnArtifactsOrEmpty
                    }
                , Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.run
                          "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                        codename.DebVersion} && source ./buildkite/scripts/export-git-env-vars.sh"
                      , loadImage
                      , Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed 's/B62qiburnzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzmp7r7UN6X/B62qrTP88hjyU3hq6QNvFafX8sgHrsAW6v7tt5twrcugJM4bBV2eu9k/g' -i config.json && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                                                                                                                                                               spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                                                                                                                                                                               spec.network} --fork-config config.json --working-dir /workdir/verification --checks config --expect-config-mismatch"
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
                      , loadImage
                      , Cmd.runInDocker
                          Cmd.Docker::{ image = image }
                          "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                   spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                                   spec.network} --fork-config config.json  --cached-hardfork-data /workdir/hardfork --working-dir /workdir/verification ${precomputed_block_prefix_arg} ${cached_tarball_ledgers} ${cached_reference_ledgers} --checks config,block,constants,artifacts --prefork-version ${spec.deb_legacy_version}"
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
                            Toolchain.Spec::{
                            , debVersion = codename.DebVersion
                            , arch = codename.Arch
                            , submodules = True
                            }
                            ([] : List Text)
                            "buildkite-cache-manager read hardfork . && ls -al ./hardfork"
                        # [ Cmd.run
                              "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                            codename.DebVersion} && source ./buildkite/scripts/export-git-env-vars.sh"
                          , loadImage
                          , Cmd.runInDocker
                              Cmd.Docker::{ image = image }
                              "curl -sL ${spec.config_json_gz_url} | gunzip > config.json && MINA_LOG_LEVEL=Spam FORKING_FROM_CONFIG_JSON=/var/lib/coda/${Network.lowerName
                                                                                                                                                            spec.network}.old.json /workdir/scripts/hardfork/mina-verify-packaged-fork-config --network ${Network.lowerName
                                                                                                                                                                                                                                                            spec.network} --fork-config config.json --cached-hardfork-data /workdir/hardfork --working-dir /workdir/hardfork ${precomputed_block_prefix_arg} ${cached_reference_ledgers} --checks ledgers,accounts  ${cached_tarball_ledgers}"
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
                      , loadImage
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
                                      ->    [ preflightCommand spec codename ]
                                          # generateHfRelatedStepsForCodename
                                              spec
                                              codename
                                              spec.codenames
                                              pipelineName
                                          # List/concatMap
                                              DebianArchPair
                                              Command.Type
                                              ( verifyImageCommand
                                                  spec
                                                  pipelineName
                                                  codename
                                              )
                                              ( Prelude.List.drop
                                                  1
                                                  DebianArchPair
                                                  spec.codenames
                                              )
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
      ->  \(use_generic_dockers_from_version : Optional Text)
      ->  \(hardfork_config_url : Optional Text)
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
              , use_generic_dockers_from_version =
                  use_generic_dockers_from_version
              , hardfork_config_url = hardfork_config_url
              }
          ).pipeline

in  { generate_hardfork_package = generate_hardfork_package }
