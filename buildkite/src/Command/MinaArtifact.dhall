let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let Optional/default = Prelude.Optional.default

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let DockerImage = ./DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DockerVersion = ../Constants/DockerVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DockerPublish = ../Constants/DockerPublish.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Toolchain = ../Constants/Toolchain.dhall

let Arch = ../Constants/Arch.dhall

let Expr = ../Pipeline/Expr.dhall

let MinaBuildSpec =
      { Type =
          { prefix : Text
          , artifacts : List Artifacts.Type
          , debVersion : DebianVersions.DebVersion
          , profile : Profiles.Type
          , network : Network.Type
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
          , docker_publish : DockerPublish.Type
          , suffix : Optional Text
          , if_ : Optional B/If
          , includeIf : List Expr.Type
          , excludeIf : List Expr.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = Artifacts.AllButTests
          , buildScript = "./buildkite/scripts/build-release.sh"
          , debVersion = DebianVersions.DebVersion.Bullseye
          , profile = Profiles.Type.Devnet
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.TestnetGeneric
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebianAndArch
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , scope = PipelineScope.Full
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          , extraBuildEnvs = [] : List Text
          , suffix = None Text
          , deb_legacy_version = "3.3.0-compatible-560d3a9"
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
               spec.debVersion} ${Network.capitalName
                                    spec.network} ${Profiles.toSuffixUppercase
                                                      spec.profile} ${BuildFlags.toSuffixUppercase
                                                                        spec.buildFlags}${Arch.labelSuffix
                                                                                            spec.arch}"

let nameSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion}${Network.capitalName
                                   spec.network}${Profiles.toSuffixUppercase
                                                    spec.profile}${BuildFlags.toSuffixUppercase
                                                                     spec.buildFlags}${Arch.nameSuffix
                                                                                         spec.arch}"

let sizeFromArch
    : Arch.Type -> Size
    =     \(arch : Arch.Type)
      ->  merge { Arm64 = Size.Arm64, Amd64 = Size.XLarge } arch

let build_artifacts
    : MinaBuildSpec.Type -> Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  Toolchain.select
                    spec.toolchainSelectMode
                    spec.debVersion
                    spec.arch
                    (   [ "DUNE_PROFILE=${Profiles.duneProfile spec.profile}"
                        , "AWS_ACCESS_KEY_ID"
                        , "AWS_SECRET_ACCESS_KEY"
                        , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                        , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                        , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                 spec.debVersion}"
                        , "ARCHITECTURE=${Arch.lowerName spec.arch}"
                        , Network.buildMainnetEnv spec.network
                        ]
                      # BuildFlags.buildEnvs spec.buildFlags
                      # spec.extraBuildEnvs
                      # DebianVersions.overrideEnvs
                    )
                    "${spec.buildScript} ${Artifacts.toDebianNames
                                             spec.artifacts
                                             spec.network}"
                # [ Cmd.run
                      "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                        spec.debVersion}"
                  , Cmd.run
                      "./buildkite/scripts/apps/write_to_cache.sh ${DebianVersions.lowerName
                                                                      spec.debVersion}"
                  ]
            , label = "Debian: Build ${labelSuffix spec}"
            , key = "build-deb-pkg${Optional/default Text "" spec.suffix}"
            , target =
                merge { Amd64 = Size.Multi, Arm64 = Size.Arm64 } spec.arch
            , if_ = spec.if_
            , retries =
              [ Command.Retry::{
                , exit_status = Command.ExitStatus.Code +2
                , limit = Some 2
                }
              ]
            }

let docker_step
    : Artifacts.Type -> MinaBuildSpec.Type -> List DockerImage.ReleaseSpec.Type
    =     \(artifact : Artifacts.Type)
      ->  \(spec : MinaBuildSpec.Type)
      ->  let step_dep_name = "build"

          let deps =
                DebianVersions.dependsOn
                  DebianVersions.DepsSpec::{
                  , deb_version = spec.debVersion
                  , network = spec.network
                  , profile = spec.profile
                  , build_flag = spec.buildFlags
                  , step = step_dep_name
                  , prefix = spec.prefix
                  , arch = spec.arch
                  }

          let size = sizeFromArch spec.arch

          in  merge
                { Daemon =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Daemon
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , verify = True
                    , arch = spec.arch
                    , size = size
                    , if_ = spec.if_
                    }
                  ]
                , DaemonConfig = [] : List DockerImage.ReleaseSpec.Type
                , DaemonAutoHardfork =
                  [ DockerImage.ReleaseSpec::{
                    , deps =
                          deps
                        # DockerVersion.dependsOn
                            DockerVersion.DepsSpec::{
                            , codename = DockerVersion.ofDebian spec.debVersion
                            , network = spec.network
                            , profile = spec.profile
                            , artifact = Artifacts.Type.Daemon
                            }
                    , service = Artifacts.Type.DaemonAutoHardfork
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , size = size
                    }
                  ]
                , DaemonLegacyHardfork =
                  [ DockerImage.ReleaseSpec::{
                    , deps =
                          deps
                        # DockerVersion.dependsOn
                            DockerVersion.DepsSpec::{
                            , codename = DockerVersion.ofDebian spec.debVersion
                            , network = spec.network
                            , profile = spec.profile
                            , artifact = Artifacts.Type.DaemonLegacyHardfork
                            }
                    , service = Artifacts.Type.DaemonLegacyHardfork
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , size = size
                    }
                  ]
                , TestExecutive = [] : List DockerImage.ReleaseSpec.Type
                , LogProc = [] : List DockerImage.ReleaseSpec.Type
                , CreateLegacyGenesis = [] : List DockerImage.ReleaseSpec.Type
                , BatchTxn =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.BatchTxn
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
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
                    , service = Artifacts.Type.DelegationVerifier
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
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
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Archive
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
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
                , Rosetta =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Rosetta
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , verify = True
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , ZkappTestTransaction =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.ZkappTestTransaction
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , deb_codename = spec.debVersion
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , FunctionalTestSuite =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.FunctionalTestSuite
                    , network = Network.Type.TestnetGeneric
                    , deb_codename = spec.debVersion
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , size = size
                    , if_ = spec.if_
                    }
                  ]
                , Toolchain = [] : List DockerImage.ReleaseSpec.Type
                }
                artifact

let docker_commands
    : MinaBuildSpec.Type -> List Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  let docker_steps =
                List/map
                  Artifacts.Type
                  (List DockerImage.ReleaseSpec.Type)
                  (\(artifact : Artifacts.Type) -> docker_step artifact spec)
                  spec.artifacts

          let flattened_docker_steps =
                Prelude.List.fold
                  (List DockerImage.ReleaseSpec.Type)
                  docker_steps
                  (List DockerImage.ReleaseSpec.Type)
                  (     \(x : List DockerImage.ReleaseSpec.Type)
                    ->  \(y : List DockerImage.ReleaseSpec.Type)
                    ->  x # y
                  )
                  ([] : List DockerImage.ReleaseSpec.Type)

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

in  { pipeline = pipeline
    , onlyDebianPipeline = onlyDebianPipeline
    , MinaBuildSpec = MinaBuildSpec
    , labelSuffix = labelSuffix
    , buildArtifacts = build_artifacts
    }
