-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Command = ./Base.dhall

let Size = ./Size.dhall

let Profiles = ../Constants/Profiles.dhall

let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Network = ../Constants/Network.dhall

let DockerPublish = ../Constants/DockerPublish.dhall

let VerifyDockers = ../Command/Packages/VerifyDockers.dhall

let Arch = ../Constants/Arch.dhall

let DebianInstallMode
    : Type
    = < ThroughLocalRepo | NoInstall | DownloadOnly >

let ciDockerCacheMountedRoot = "/var/storagebox/docker-cache"

let ReleaseSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , network : Network.Type
          , service : Artifacts.Type
          , version : Text
          , branch : Text
          , repo : Text
          , arch : Arch.Type
          , no_cache : Bool
          , deb_install_mode : DebianInstallMode
          , deb_codename : DebianVersions.DebVersion
          , deb_release : Text
          , deb_version : Text
          , deb_root_folder : Text
          , deb_legacy_version : Text
          , deb_storage_repair_version : Optional Text
          , deb_suffix : Optional Text
          , deb_profile : Profiles.Type
          , deb_repo : DebianRepo.Type
          , build_flags : BuildFlags.Type
          , step_key_suffix : Text
          , docker_publish : DockerPublish.Type
          , docker_repo : DockerRepo.Type
          , save_to_ci_cache : Bool
          , image_name : Optional Text
          , generic : Bool
          , verify : Bool
          , size : Size
          , if_ : Optional B/If
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , network = Network.Type.Devnet
          , arch = Arch.Type.Amd64
          , version = "\\\${MINA_DOCKER_TAG}"
          , service = Artifacts.Type.Daemon
          , branch = "\\\${BUILDKITE_BRANCH}"
          , repo = "\\\${BUILDKITE_REPO}"
          , deb_install_mode = DebianInstallMode.ThroughLocalRepo
          , deb_root_folder = "\\\${BUILDKITE_BUILD_ID}"
          , deb_codename = DebianVersions.DebVersion.Bullseye
          , deb_release = "unstable"
          , deb_version = "\\\${MINA_DEB_VERSION}"
          , deb_legacy_version = "3.1.1-alpha1-compatible-14a8b92"
          , deb_storage_repair_version = None Text
          , deb_profile = Profiles.Type.Devnet
          , build_flags = BuildFlags.Type.None
          , deb_repo = DebianRepo.Type.Local
          , docker_publish = DockerPublish.Type.Essential
          , no_cache = False
          , save_to_ci_cache = False
          , docker_repo = DockerRepo.Type.InternalEurope
          , step_key_suffix = "-docker-image"
          , verify = False
          , deb_suffix = None Text
          , image_name = None Text
          , if_ = None B/If
          , generic = False
          }
      }

let stepKey =
          \(spec : ReleaseSpec.Type)
      ->  "${Artifacts.lowerName spec.service}${spec.step_key_suffix}"

let stepLabel =
          \(spec : ReleaseSpec.Type)
      ->  "Docker: ${Artifacts.capitalName
                       spec.service} ${Network.capitalName
                                         spec.network} ${DebianVersions.capitalName
                                                           spec.deb_codename} ${Profiles.toSuffixUppercase
                                                                                  spec.deb_profile} ${BuildFlags.toSuffixUppercase
                                                                                                        spec.build_flags} ${Arch.capitalName
                                                                                                                              spec.arch}"

let generateStep =
          \(spec : ReleaseSpec.Type)
      ->  let exportMinaDebCmd =
                "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                              spec.deb_codename}"

          let exportBranchNameCmd = "export BRANCH_NAME=${spec.branch}"

          let maybeCacheOption = if spec.no_cache then "--no-cache" else ""

          let maybeStartDebianRepo =
                merge
                  { ThroughLocalRepo =
                      " && ./buildkite/scripts/debian/start_local_repo.sh --root ${spec.deb_root_folder} --arch ${Arch.lowerName
                                                                                                                    spec.arch}"
                  , DownloadOnly =
                      " && ROOT=${spec.deb_root_folder} LOCAL_DEB_FOLDER=\"dockerfiles\" ./buildkite/scripts/debian/read_all_from_cache.sh "
                  , NoInstall = " && echo Skipping local debian repo setup "
                  }
                  spec.deb_install_mode

          let maybeStopDebianRepo =
                merge
                  { ThroughLocalRepo = " && ./scripts/debian/aptly.sh stop"
                  , DownloadOnly =
                      " && echo Skipping local debian repo teardown "
                  , NoInstall = " && echo Skipping local debian repo teardown "
                  }
                  spec.deb_install_mode

          let debSuffix =
                merge
                  { None = if spec.generic then " --deb-suffix generic" else ""
                  , Some = \(s : Text) -> " --deb-suffix " ++ s
                  }
                  spec.deb_suffix

          let imageNameArg =
                merge
                  { None = ""
                  , Some = \(name : Text) -> " --image-name " ++ name
                  }
                  spec.image_name

          let archCustomSuffix =
                merge
                  { Arm64 = " --custom-suffix arm64 ", Amd64 = "" }
                  spec.arch

          let customSuffix =
                merge
                  { DaemonConfig = archCustomSuffix
                  , Daemon = ""
                  , DaemonLegacyHardfork = ""
                  , DaemonAppsOnly = ""
                  , DaemonPrefork = ""
                  , DaemonAutoHardfork = ""
                  , DaemonAutomode = ""
                  , LogProc = ""
                  , Archive = ""
                  , TestExecutive = ""
                  , BatchTxn = ""
                  , Rosetta = ""
                  , RosettaAppsOnly = ""
                  , RosettaConfig = archCustomSuffix
                  , ZkappTestTransaction = ""
                  , FunctionalTestSuite = ""
                  , Toolchain = ""
                  , CreatePreforkGenesis = ""
                  , DelegationVerifier = ""
                  , DaemonStorageToolbox = ""
                  }
                  spec.service

          let storageRepairVersionSuffix =
                merge
                  { None = ""
                  , Some = \(v : Text) -> " --deb-storage-repair-version ${v} "
                  }
                  spec.deb_storage_repair_version

          let maybeVerify =
                      if     spec.verify
                         &&  DockerPublish.shouldPublish
                               spec.docker_publish
                               spec.service

                then      " && "
                      ++  VerifyDockers.verify
                            VerifyDockers.Spec::{
                            , artifacts = [ spec.service ]
                            , networks = [ spec.network ]
                            , version = spec.deb_version
                            , codenames = [ spec.deb_codename ]
                            , profile = spec.deb_profile
                            , buildFlag = spec.build_flags
                            , archs = [ spec.arch ]
                            , repo = spec.docker_repo
                            , generic = spec.generic
                            }

                else  ""

          let pruneDockerImages =
                    "if [ -z \"\\\${SKIP_DOCKER_PRUNE:-}\" ]; then "
                ++  "docker system prune --all --force "
                ++  merge
                      { Arm64 = ""
                      , XLarge = "--filter until=24h"
                      , Large = "--filter until=24h"
                      , Medium = "--filter until=24h"
                      , Small = "--filter until=24h"
                      , Integration = "--filter until=24h"
                      , QA = "--filter until=24h"
                      , Multi = "--filter until=24h"
                      , Perf = "--filter until=24h"
                      }
                      spec.size
                ++  "; else echo 'Skipping docker prune due to SKIP_DOCKER_PRUNE'; fi"

          let loadOnlyArg =
                      if DockerPublish.shouldPublish
                           spec.docker_publish
                           spec.service

                then  ""

                else  " --load-only "

          let serviceName = Artifacts.dockerServiceName spec.service

          let maybeSaveToCacheArg =
                      if spec.save_to_ci_cache

                then  " --save-to-ci-cache ${ciDockerCacheMountedRoot} "

                else  ""

          let buildDockerCmd =
                    "./scripts/docker/build.sh"
                ++  " --service ${serviceName}"
                ++  " --network ${Network.debianSuffix spec.network}"
                ++  " --version ${spec.version}"
                ++  " --branch ${spec.branch}"
                ++  " ${maybeCacheOption} "
                ++  " --deb-codename ${DebianVersions.lowerName
                                         spec.deb_codename}"
                ++  " --deb-repo ${DebianRepo.address spec.deb_repo}"
                ++  " --deb-release ${spec.deb_release}"
                ++  " --deb-version ${spec.deb_version}"
                ++  " --deb-profile ${Profiles.lowerName spec.deb_profile}"
                ++  " --deb-build-flags ${BuildFlags.lowerName
                                            spec.build_flags}"
                ++  " --deb-legacy-version ${spec.deb_legacy_version}"
                ++  debSuffix
                ++  storageRepairVersionSuffix
                ++  " --repo ${spec.repo}"
                ++  " --platform ${Arch.platform spec.arch}"
                ++  " --docker-registry ${DockerRepo.show spec.docker_repo}"
                ++  loadOnlyArg
                ++  customSuffix
                ++  imageNameArg
                ++  maybeSaveToCacheArg

          let remoteRepoCmds =
                [ Cmd.run
                    (     exportMinaDebCmd
                      ++  " && "
                      ++  exportBranchNameCmd
                      ++  " && source ./buildkite/scripts/export-git-env-vars.sh "
                      ++  " && "
                      ++  buildDockerCmd
                      ++  maybeVerify
                    )
                ]

          let commands =
                merge
                  { Unstable = remoteRepoCmds
                  , Nightly = remoteRepoCmds
                  , Stable = remoteRepoCmds
                  , Local =
                    [ Cmd.run
                        (     exportMinaDebCmd
                          ++  " && "
                          ++  exportBranchNameCmd
                          ++  " && "
                          ++  pruneDockerImages
                          ++  maybeStartDebianRepo
                          ++  " && source ./buildkite/scripts/export-git-env-vars.sh "
                          ++  " && "
                          ++  buildDockerCmd
                          ++  maybeStopDebianRepo
                          ++  maybeVerify
                        )
                    ]
                  }
                  spec.deb_repo

          let target =
                merge { Arm64 = Size.Arm64, Amd64 = Size.XLarge } spec.arch

          in  Command.build
                Command.Config::{
                , commands = commands
                , label = "${stepLabel spec}"
                , key = "${stepKey spec}"
                , target = target
                , docker_login = Some DockerLogin::{=}
                , depends_on = spec.deps
                , if_ = spec.if_
                }

in  { generateStep = generateStep
    , DebianInstallMode = DebianInstallMode
    , ReleaseSpec = ReleaseSpec
    , stepKey = stepKey
    , stepLabel = stepLabel
    }
