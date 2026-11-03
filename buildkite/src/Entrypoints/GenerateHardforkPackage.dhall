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
    -- The registry the images are tagged for. Nothing here pushes: every
    -- image goes to this build's cache (build.sh --build-cache-dir) and the
    -- publish pipeline pushes it from there, after the verification, exactly
    -- as it does for a release (Jobs/Release/PublishDockers.dhall). The
    -- hardfork default is the internal euro registry. A fork-day run sets
    -- MINA_RELEASE_DOCKER_REPO to Public, so the tags name docker.io, and
    -- lets MINA_RELEASE_DOCKER_MIRROR in the publish pipeline add the euro
    -- copy.
      DockerRepo.effective DockerRepo.Type.InternalEurope

let buildCacheDir = MinaArtifact.ownBuildCacheDir

let debianChannel =
    -- The channel the packages are built for, so their Suite matches the
    -- channel the publish pipeline is pointed at (MINA_RELEASE_CHANNEL, the
    -- same variable). Unstable unless the pipeline says otherwise.
      DebianChannel.effective DebianChannel.Type.Unstable

let cachedDockerSpec =
    -- The image step as the hardfork pipeline wants it: tagged for the
    -- registry above, kept on the agent (--load-only) and written to this
    -- build's cache, never pushed. The layered bases (generic -> profiled ->
    -- configured) come from the same cache, except when the generic images
    -- are taken from a version in the registry: then there is no cached
    -- base, and build.sh pulls it.
          \(fromRegistry : Bool)
      ->  \(docker : DockerImage.ReleaseSpec.Type)
      ->      docker
          //  { docker_repo = dockerRepo
              , docker_publish = DockerPublish.Type.Disabled
              , deb_release = debianChannel
              , build_cache_dir = Some buildCacheDir
              , base_cache_dir =
                  if fromRegistry then None Text else Some buildCacheDir
              }

let BlockStep =
    -- A Buildkite block step: the build pauses here until someone unblocks
    -- it. blocked_state "passed" shows a build nobody unblocks as passed,
    -- which is what a dry run is.
      { block : Text
      , prompt : Text
      , key : Text
      , depends_on : List Text
      , blocked_state : Text
      }

let TriggerStep =
    -- A Buildkite trigger step: starts a build of another pipeline. async
    -- False keeps this build running until that one ends, and takes its
    -- result, so the hardfork build is red when the publish failed.
      { trigger : Text
      , label : Text
      , key : Text
      , depends_on : List Text
      , async : Bool
      , build :
          { message : Text
          , branch : Text
          , commit : Text
          , env : List { mapKey : Text, mapValue : Text }
          }
      }

let Step =
    -- The command steps are Buildkite command steps as everywhere else in
    -- this repository; the publish gate adds a block and a trigger step,
    -- which the shared pipeline type has no room for. dhall-to-yaml renders
    -- a union as its contents, so each alternative is one plain step.
      < Command : Command.Type | Block : BlockStep | Trigger : TriggerStep >

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
                          (cachedDockerSpec fromRegistry docker)
                  )
                  dockerSpecs

let generateHfRelatedStepsForCodename =
          \(spec : Spec.Type)
      ->  \(codename : DebianArchPair)
      ->  \(codenames : List DebianArchPair)
      ->  \(pipelineName : Text)
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

          let loadImage =
              -- The daemon image is never pushed; the verification takes it
              -- from this build's cache, where its build step wrote it.
                Cmd.run
                  "CACHE_ROOT=${buildCacheDir} ./buildkite/scripts/docker/load_from_cache.sh ${image}"

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
                    , depends_on = dependsOnTarballs
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
                      , loadImage
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

let publishPipeline =
    -- The publish pipeline of the network. The devnet one is spelled
    -- "devet" in Buildkite, and a trigger must name the slug as it is.
          \(network : Network.Type)
      ->  merge
            { Devnet = "mina-devet-publish", Mainnet = "mina-mainnet-publish" }
            network

let publishGate =
    -- "Publish?" after everything is built and verified, then the publish
    -- pipeline of the network, started with this build's id as the cache
    -- root and the registry and channel this build was rendered with, so
    -- the two cannot disagree. Where the images and packages go is that
    -- pipeline's own setting (MINA_RELEASE_DOCKER_MIRROR, the debian
    -- repositories, the tag globs). The $\{BUILDKITE_*\} below are filled
    -- in by `buildkite-agent pipeline upload`, with the values of this
    -- build: they are not escaped on purpose, unlike the ones the command
    -- steps defer to the agent's shell.
          \(spec : Spec.Type)
      ->  \(pipelineName : Text)
      ->  \(commandKeys : List Text)
      ->  let gateKey = "_${pipelineName}-publish-gate"

          in  [ Step.Block
                  { block = "Publish?"
                  , prompt =
                      "Start ${publishPipeline
                                 spec.network} with this build's images and packages. A build that is not published is a dry run."
                  , key = gateKey
                  , depends_on = commandKeys
                  , blocked_state = "passed"
                  }
              , Step.Trigger
                  { trigger = publishPipeline spec.network
                  , label =
                      ":rocket: Publish via ${publishPipeline spec.network}"
                  , key = "_${pipelineName}-publish"
                  , depends_on = [ gateKey ]
                  , async = False
                  , build =
                      { message =
                          "Publish hardfork build \${BUILDKITE_BUILD_NUMBER} of \${BUILDKITE_BRANCH}"
                      , branch = "\${BUILDKITE_BRANCH}"
                      , commit = "\${BUILDKITE_COMMIT}"
                      , env = toMap
                          { MINA_READ_CACHE_ROOT = "\${BUILDKITE_BUILD_ID}"
                          , MINA_RELEASE_DOCKER_REPO =
                              DockerRepo.envValue dockerRepo
                          , MINA_RELEASE_CHANNEL = debianChannel
                          }
                      }
                  }
              ]

let pipeline =
          \(spec : Spec.Type)
      ->  let pipelineName = "GenerateHardforkPackage"

          let commandSteps =
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

          let built =
                Pipeline.build
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
                  , steps = commandSteps
                  }

          let commands = built.pipeline.steps

          let commandKeys =
                List/map
                  Command.Type
                  Text
                  (     \(c : Command.Type)
                    ->  Prelude.Optional.default Text "" c.key
                  )
                  commands

          let gate =
                      if Prelude.List.null Command.Type commands

                then  [] : List Step

                else  publishGate spec pipelineName commandKeys

          in  { steps = List/map Command.Type Step Step.Command commands # gate
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
      ->  pipeline
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
            }

in  { generate_hardfork_package = generate_hardfork_package }
