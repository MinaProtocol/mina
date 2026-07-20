-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Command = ./Base.dhall

let Size = ./Size.dhall

let Profiles = ../Constants/Profiles.dhall

let Docker = ../Constants/Docker/Package.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Network = ../Constants/Network.dhall

let DockerPublish = ../Constants/Docker/Publish.dhall

let VerifyDockers = ../Command/Packages/VerifyDockers.dhall

let Arch = ../Constants/Arch.dhall

let DebianInstallMode
    : Type
    = < NoInstall | DownloadOnly >

let ciDockerCacheMountedRoot = "/var/storagebox/docker-cache"

let ReleaseSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , network : Network.Type
          , service : Docker.Type
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
          , service = Docker.Type.Daemon { network = Network.Type.Devnet }
          , branch = "\\\${BUILDKITE_BRANCH}"
          , repo = "\\\${BUILDKITE_REPO}"
          , deb_install_mode = DebianInstallMode.DownloadOnly
          , deb_root_folder = "\\\${BUILDKITE_BUILD_ID}"
          , deb_codename = DebianVersions.DebVersion.Bullseye
          , deb_release = "unstable"
          , deb_version = "\\\${MINA_DEB_VERSION}"
          , deb_legacy_version = "3.1.1-alpha1-compatible-14a8b92"
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
      ->  let segment =
                      if Docker.isProfiled spec.service

                then  Profiles.lowerName spec.deb_profile

                else  Network.lowerName spec.network

          in  "${Docker.lowerName
                   spec.service}-${segment}${spec.step_key_suffix}"

let stepLabel =
          \(spec : ReleaseSpec.Type)
      ->  "Docker: ${Docker.capitalName
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
                  { DownloadOnly =
                      " && ROOT=${spec.deb_root_folder} LOCAL_DEB_FOLDER=\"dockerfiles\" ./buildkite/scripts/debian/read_all_from_cache.sh "
                  , NoInstall = " && echo Skipping local debian repo setup "
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
              -- Only Daemon/Rosetta ("*-config" images) need an arch marker
              -- baked into the custom suffix build-arg on top of --platform;
              -- --platform alone already derives -arm64 for everyone else
              -- (scripts/docker/helper.sh get_platform_suffix), which is the
              -- only arch suffix manager.sh verify's tag ever expects.
                merge
                  { DaemonGeneric = ""
                  , DaemonProfiled = \(args : { profile : Profiles.Type }) -> ""
                  , Daemon =
                      \(args : { network : Network.Type }) -> archCustomSuffix
                  , DaemonLegacyHardfork =
                      \(args : { network : Network.Type }) -> ""
                  , DaemonAutoHardfork =
                      \(args : { network : Network.Type }) -> ""
                  , Archive = \(args : { network : Network.Type }) -> ""
                  , RosettaGeneric = ""
                  , Rosetta =
                      \(args : { network : Network.Type }) -> archCustomSuffix
                  , TxTools = ""
                  , DelegationVerifier = ""
                  , Toolchain = ""
                  }
                  spec.service

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
              -- Single source of truth for the prune (see disk-cleanup.sh).
              -- THRESHOLD=0 forces it before every build (builds are the heavy
              -- disk consumers); the script is concurrency-safe (dangling-only,
              -- keeps tagged images for co-located jobs) and honours
              -- SKIP_DOCKER_PRUNE itself.
                "DISK_PRUNE_THRESHOLD=0 ./buildkite/scripts/docker/disk-cleanup.sh"

          let loadOnlyArg =
                      if DockerPublish.shouldPublish
                           spec.docker_publish
                           spec.service

                then  ""

                else  " --load-only "

          let serviceName = Docker.serviceName spec.service

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
                      ++  pruneDockerImages
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
                          ++  maybeVerify
                        )
                    ]
                  }
                  spec.deb_repo

          let target =
                merge { Arm64 = Size.XLarge, Amd64 = Size.XLarge } spec.arch

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
