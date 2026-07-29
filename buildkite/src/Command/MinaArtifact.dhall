let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let List/concatMap = Prelude.List.concatMap

let Optional/default = Prelude.Optional.default

let Text/concatSep = Prelude.Text.concatSep

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let DockerImage = ./DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DockerPublish = ../Constants/Docker/Publish.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Docker = ../Constants/Docker/Package.dhall

let Artifact = ../Constants/Artifact/Artifacts.dhall

let Toolchain = ../Constants/Toolchain.dhall

let Arch = ../Constants/Arch.dhall

let Expr = ../Pipeline/Expr.dhall

let MinaBuildSpec =
      { Type =
          { prefix : Text
          , artifacts : List Artifact.Type
          , debVersion : DebianVersions.DebVersion
          , buildFlags : BuildFlags.Type
          , toolchainSelectMode : Toolchain.SelectionMode
          , extraBuildEnvs : List Text
          , scope : List PipelineScope.Type
          , tags : List PipelineTag.Type
          , channel : DebianChannel.Type
          , debianRepo : DebianRepo.Type
          , buildScript : Text
          , arch : Arch.Type
          , deb_legacy_version : Text
          , deb_legacy_githash_config : Text
          , docker_publish : DockerPublish.Type
          , suffix : Optional Text
          , if_ : Optional B/If
          , includeIf : List Expr.Type
          , excludeIf : List Expr.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = [ Artifact.Type.LogProc ]
          , buildScript = "./buildkite/scripts/build-release.sh"
          , debVersion = DebianVersions.DebVersion.Bullseye
          , buildFlags = BuildFlags.Type.None
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebianAndArch
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , scope = PipelineScope.Full
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          , extraBuildEnvs = [] : List Text
          , suffix = None Text
          , deb_legacy_version = "3.4.0-alpha1-compatible-ad13ff4"
          , deb_legacy_githash_config = ""
          , arch = Arch.Type.Amd64
          , docker_publish = DockerPublish.Type.Essential
          , if_ = None B/If
          , includeIf = [] : List Expr.Type
          , excludeIf = [] : List Expr.Type
          }
      }

let labelSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion} ${BuildFlags.toSuffixUppercase
                                    spec.buildFlags}${Arch.labelSuffix
                                                        spec.arch}"

let primaryNetwork
    : MinaBuildSpec.Type -> Network.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  Optional/default
            Network.Type
            Network.Type.Devnet
            (List/head Network.Type (Artifact.networks spec.artifacts))

let baseNameSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion}${BuildFlags.toSuffixUppercase
                                   spec.buildFlags}${Arch.nameSuffix spec.arch}"

let nameSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${Network.namePrefixSegment (primaryNetwork spec)}${baseNameSuffix
                                                                 spec}"

let selfName
    : MinaBuildSpec.Type -> Text
    = \(spec : MinaBuildSpec.Type) -> "${spec.prefix}${nameSuffix spec}"

let genericBuildName
    : MinaBuildSpec.Type -> Text
    = \(spec : MinaBuildSpec.Type) -> "${spec.prefix}${baseNameSuffix spec}"

let DockerService =
      { service : Docker.Type, network : Network.Type, profile : Profiles.Type }

let expandDockerServices =
          \(artifact : Artifact.Type)
      ->  let net = Artifact.resolvedNetwork artifact

          let prof = Artifact.profile artifact

          let mk =
                    \(svc : Docker.Type)
                ->  { service = svc, network = net, profile = prof }

          let none = [] : List DockerService

          in  merge
                { Daemon =
                        \(_ : { network : Network.Type })
                    ->  [ mk (Docker.Type.Daemon { network = net }) ]
                , DaemonGeneric = [ mk Docker.Type.DaemonGeneric ]
                , DaemonProfiled =
                        \(_ : { profile : Profiles.Type })
                    ->  [ mk (Docker.Type.DaemonProfiled { profile = prof }) ]
                , DaemonLegacyHardfork =
                        \(_ : { network : Network.Type })
                    ->  [ mk
                            (Docker.Type.DaemonLegacyHardfork { network = net })
                        ]
                , DaemonAutoHardfork =
                        \(_ : { network : Network.Type })
                    ->  [ mk (Docker.Type.DaemonAutoHardfork { network = net })
                        ]
                , DaemonPrefork = \(_ : { network : Network.Type }) -> none
                , DaemonPostfork = \(_ : { network : Network.Type }) -> none
                , CreatePreforkGenesis =
                    \(_ : { network : Network.Type }) -> none
                , DaemonStorageToolbox = none
                , LogProc = none
                , ArchiveGeneric = none
                , Archive =
                        \(_ : { network : Network.Type })
                    ->  [ mk (Docker.Type.Archive { network = net }) ]
                , RosettaGeneric = none
                , Rosetta =
                        \(_ : { network : Network.Type })
                    ->  [ mk Docker.Type.RosettaGeneric
                        , mk (Docker.Type.Rosetta { network = net })
                        ]
                , TestExecutive = none
                , TxTools = none
                , FunctionalTestSuite = none
                , DelegationVerifier = [ mk Docker.Type.DelegationVerifier ]
                , Toolchain = none
                }
                artifact

let build_artifacts
    : MinaBuildSpec.Type -> Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  let nets = Artifact.networks spec.artifacts

          let debianTokens =
                Text/concatSep
                  " "
                  ( List/map
                      Artifact.Type
                      Text
                      Artifact.toDebianToken
                      spec.artifacts
                  )

          let appsCacheWrites =
                List/map
                  Network.Type
                  Cmd.Type
                  (     \(net : Network.Type)
                    ->  Cmd.run
                          "./buildkite/scripts/apps/write_to_cache.sh ${DebianVersions.lowerName
                                                                          spec.debVersion} ${Network.lowerName
                                                                                               net}-${Profiles.toSuffixLowercase
                                                                                                        ( Profiles.fromNetwork
                                                                                                            net
                                                                                                        )}${BuildFlags.toLabelSegment
                                                                                                              spec.buildFlags}${Arch.toSuffixLowercase
                                                                                                                                  spec.arch}"
                  )
                  nets

          in  Command.build
                Command.Config::{
                , commands =
                      Toolchain.select
                        Toolchain.Spec::{
                        , mode = spec.toolchainSelectMode
                        , debVersion = spec.debVersion
                        , arch = spec.arch
                        , submodules = True
                        }
                        (   [ "AWS_ACCESS_KEY_ID"
                            , "AWS_SECRET_ACCESS_KEY"
                            , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                            , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                            , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                     spec.debVersion}"
                            , "ARCHITECTURE=${Arch.lowerName spec.arch}"
                            , Network.foldMinaBuildMainnetEnv nets
                            , "PREFORK_LEGACY_VERSION=${spec.deb_legacy_version}"
                            , "PREFORK_GITHASH_CONFIG=${spec.deb_legacy_githash_config}"
                            ]
                          # BuildFlags.buildEnvs spec.buildFlags
                          # spec.extraBuildEnvs
                          # DebianVersions.overrideEnvs
                        )
                        "${spec.buildScript} ${debianTokens} profile_devnet_generic profile_mainnet_generic"
                    # [ Cmd.run
                          "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                            spec.debVersion}"
                      ]
                    # appsCacheWrites
                , label = "Debian: Build ${labelSuffix spec}"
                , key = "build-deb-pkg${Optional/default Text "" spec.suffix}"
                , target = Size.Multi
                , if_ = spec.if_
                , retries =
                  [ Command.Retry::{
                    , exit_status = Command.ExitStatus.Code +2
                    , limit = Some 2
                    }
                  ]
                }

let commonBuildEnvs =
          \(spec : MinaBuildSpec.Type)
      ->  let nets = Artifact.networks spec.artifacts

          in    [ "AWS_ACCESS_KEY_ID"
                , "AWS_SECRET_ACCESS_KEY"
                , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                         spec.debVersion}"
                , "ARCHITECTURE=${Arch.lowerName spec.arch}"
                , Network.foldMinaBuildMainnetEnv nets
                , "PREFORK_LEGACY_VERSION=${spec.deb_legacy_version}"
                , "PREFORK_GITHASH_CONFIG=${spec.deb_legacy_githash_config}"
                ]
              # BuildFlags.buildEnvs spec.buildFlags
              # spec.extraBuildEnvs
              # DebianVersions.overrideEnvs

let treeVariant =
          \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.lowerName
               spec.debVersion}${BuildFlags.toLabelSegment
                                   spec.buildFlags}${Arch.toSuffixLowercase
                                                       spec.arch}"

let appsJobName
    : MinaBuildSpec.Type -> Text
    = \(spec : MinaBuildSpec.Type) -> "${selfName spec}Apps"

let primaryAppsVariant
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  let primary =
                Optional/default
                  Network.Type
                  Network.Type.Devnet
                  (List/head Network.Type (Artifact.networks spec.artifacts))

          in  "${Network.lowerName
                   primary}-${Profiles.toSuffixLowercase
                                ( Profiles.fromNetwork primary
                                )}${BuildFlags.toLabelSegment
                                      spec.buildFlags}${Arch.toSuffixLowercase
                                                          spec.arch}"

let build_apps
    : MinaBuildSpec.Type -> Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  let nets = Artifact.networks spec.artifacts

          let appsCacheWrites =
                List/map
                  Network.Type
                  Cmd.Type
                  (     \(net : Network.Type)
                    ->  Cmd.run
                          "./buildkite/scripts/apps/write_to_cache.sh ${DebianVersions.lowerName
                                                                          spec.debVersion} ${Network.lowerName
                                                                                               net}-${Profiles.toSuffixLowercase
                                                                                                        ( Profiles.fromNetwork
                                                                                                            net
                                                                                                        )}${BuildFlags.toLabelSegment
                                                                                                              spec.buildFlags}${Arch.toSuffixLowercase
                                                                                                                                  spec.arch}"
                  )
                  nets

          in  Command.build
                Command.Config::{
                , commands =
                      Toolchain.select
                        Toolchain.Spec::{
                        , mode = spec.toolchainSelectMode
                        , debVersion = spec.debVersion
                        , arch = spec.arch
                        , submodules = True
                        }
                        (commonBuildEnvs spec)
                        "./buildkite/scripts/build-artifact.sh"
                    # appsCacheWrites
                    # [ Cmd.run
                          "./buildkite/scripts/apps/write_build_manifest_to_cache.sh ${DebianVersions.lowerName
                                                                                         spec.debVersion} ${treeVariant
                                                                                                              spec}"
                      ]
                , label = "Build apps: ${labelSuffix spec}"
                , key = "build-apps"
                , target = Size.Multi
                , if_ = spec.if_
                , retries =
                  [ Command.Retry::{
                    , exit_status = Command.ExitStatus.Code +2
                    , limit = Some 2
                    }
                  ]
                }

let build_debian
    : MinaBuildSpec.Type -> Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  let debianTokens =
                Text/concatSep
                  " "
                  ( List/map
                      Artifact.Type
                      Text
                      Artifact.toDebianToken
                      spec.artifacts
                  )

          in  Command.build
                Command.Config::{
                , commands =
                      Toolchain.select
                        Toolchain.Spec::{
                        , mode = spec.toolchainSelectMode
                        , debVersion = spec.debVersion
                        , arch = spec.arch
                        , submodules = False
                        }
                        (commonBuildEnvs spec)
                        "./buildkite/scripts/debian/build-from-cache.sh ${primaryAppsVariant
                                                                            spec} ${treeVariant
                                                                                      spec} ${debianTokens} profile_devnet_generic profile_mainnet_generic"
                    # [ Cmd.run
                          "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                            spec.debVersion}"
                      ]
                , label = "Debian: Build ${labelSuffix spec}"
                , key = "build-deb-pkg${Optional/default Text "" spec.suffix}"
                , depends_on =
                  [ { name = appsJobName spec, key = "build-apps" } ]
                , target = Size.Multi
                , if_ = spec.if_
                , retries =
                  [ Command.Retry::{
                    , exit_status = Command.ExitStatus.Code +2
                    , limit = Some 2
                    }
                  ]
                }

let docker_step
    : DockerService -> MinaBuildSpec.Type -> List DockerImage.ReleaseSpec.Type
    =     \(entry : DockerService)
      ->  \(spec : MinaBuildSpec.Type)
      ->  let network = entry.network

          let profile = entry.profile

          let netSeg = "-${Network.lowerName network}-docker-image"

          let deps
              : List Command.TaggedKey.Type
              = [ { name = selfName spec, key = "build-deb-pkg" } ]

          let withDocker =
                    \(dep : Docker.Type)
                ->    deps
                    # [ { name = selfName spec
                        , key = "${Docker.lowerName dep}${netSeg}"
                        }
                      ]

          let genericNetwork = Network.Type.Devnet

          let dependsOnGeneric =
                  deps
                # [ { name = genericBuildName spec
                    , key =
                        "${Docker.lowerName
                             Docker.Type.DaemonGeneric}-${Network.lowerName
                                                            genericNetwork}-docker-image"
                    }
                  ]

          let size = Size.XLarge

          in  merge
                { DaemonAutoHardfork =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps =
                              withDocker
                                (Docker.Type.Daemon { network = network })
                          , service =
                              Docker.Type.DaemonAutoHardfork
                                { network = network }
                          , network = network
                          , deb_codename = spec.debVersion
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , docker_publish = spec.docker_publish
                          , deb_repo = DebianRepo.Type.Local
                          , deb_legacy_version = spec.deb_legacy_version
                          , size = size
                          }
                        ]
                , DaemonLegacyHardfork =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps =
                              withDocker
                                ( Docker.Type.DaemonLegacyHardfork
                                    { network = network }
                                )
                          , service =
                              Docker.Type.DaemonLegacyHardfork
                                { network = network }
                          , network = network
                          , deb_codename = spec.debVersion
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , docker_publish = spec.docker_publish
                          , deb_repo = DebianRepo.Type.Local
                          , deb_legacy_version = spec.deb_legacy_version
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , DaemonGeneric =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.DaemonGeneric
                    , network = genericNetwork
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , generic = True
                    , verify = True
                    , arch = spec.arch
                    , size = size
                    }
                  ]
                , DaemonProfiled =
                        \(args : { profile : Profiles.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = dependsOnGeneric
                          , service = entry.service
                          , network = network
                          , deb_codename = spec.debVersion
                          , docker_publish = spec.docker_publish
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , deb_install_mode =
                              DockerImage.DebianInstallMode.DownloadOnly
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , Daemon =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = dependsOnGeneric
                          , service = Docker.Type.Daemon { network = network }
                          , network = network
                          , deb_codename = spec.debVersion
                          , docker_publish = spec.docker_publish
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , deb_install_mode =
                              DockerImage.DebianInstallMode.DownloadOnly
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , TxTools =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.TxTools
                    , network = network
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , DelegationVerifier =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.DelegationVerifier
                    , network = network
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , Archive =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = deps
                          , service = Docker.Type.Archive { network = network }
                          , network = network
                          , deb_codename = spec.debVersion
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , docker_publish = spec.docker_publish
                          , deb_repo = DebianRepo.Type.Local
                          , deb_legacy_version = spec.deb_legacy_version
                          , verify = True
                          , arch = spec.arch
                          , if_ = spec.if_
                          , size = size
                          }
                        ]
                , RosettaGeneric =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.RosettaGeneric
                    , network = network
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , generic = True
                    , verify = True
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , Rosetta =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = withDocker Docker.Type.RosettaGeneric
                          , service = Docker.Type.Rosetta { network = network }
                          , network = network
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , image_name = Some
                              ( Docker.dockerName
                                  (Docker.Type.Rosetta { network = network })
                              )
                          , deb_codename = spec.debVersion
                          , docker_publish = spec.docker_publish
                          , deb_install_mode =
                              DockerImage.DebianInstallMode.DownloadOnly
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , Toolchain = [] : List DockerImage.ReleaseSpec.Type
                }
                entry.service

let docker_commands
    : MinaBuildSpec.Type -> List Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  let services =
                List/concatMap
                  Artifact.Type
                  DockerService
                  expandDockerServices
                  spec.artifacts

          let flattened_docker_steps =
                List/concatMap
                  DockerService
                  DockerImage.ReleaseSpec.Type
                  (\(e : DockerService) -> docker_step e spec)
                  services

          in  List/map
                DockerImage.ReleaseSpec.Type
                Command.Type
                (     \(s : DockerImage.ReleaseSpec.Type)
                  ->  DockerImage.generateStep s
                )
                flattened_docker_steps

let pipelineBuilder
    : MinaBuildSpec.Type -> List Command.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  \(steps : List Command.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen spec.debVersion
            , path = "Release"
            , name = "${spec.prefix}${nameSuffix spec}"
            , tags = spec.tags
            , scope = spec.scope
            , includeIf = spec.includeIf
            , excludeIf = spec.excludeIf
            }
          , steps = steps
          }

let onlyDebianPipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder spec [ build_artifacts spec ]

let pipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder spec ([ build_artifacts spec ] # docker_commands spec)

let appsPipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen spec.debVersion
            , path = "Release"
            , name = "${appsJobName spec}"
            , tags = spec.tags
            , scope = spec.scope
            , includeIf = spec.includeIf
            , excludeIf = spec.excludeIf
            }
          , steps = [ build_apps spec ]
          }

let packagePipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.packageDirtyWhen
            , path = "Release"
            , name = "${spec.prefix}${nameSuffix spec}"
            , tags = spec.tags
            , scope = spec.scope
            , includeIf = spec.includeIf
            , excludeIf = spec.excludeIf
            }
          , steps = [ build_debian spec ] # docker_commands spec
          }

in  { pipeline = pipeline
    , onlyDebianPipeline = onlyDebianPipeline
    , appsPipeline = appsPipeline
    , packagePipeline = packagePipeline
    , MinaBuildSpec = MinaBuildSpec
    , labelSuffix = labelSuffix
    , buildArtifacts = build_artifacts
    , buildApps = build_apps
    , buildDebian = build_debian
    }
