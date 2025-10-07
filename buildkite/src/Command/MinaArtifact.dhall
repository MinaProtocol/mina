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
          , suffix : Optional Text
          , if_ : Optional B/If
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = Artifacts.AllButTests
          , buildScript = "./buildkite/scripts/build-release.sh"
          , debVersion = DebianVersions.DebVersion.Bullseye
          , profile = Profiles.Type.PublicNetwork
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Base
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebianAndArch
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , scope = PipelineScope.Full
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          , extraBuildEnvs = [] : List Text
          , suffix = None Text
          , deb_legacy_version = "3.1.1-alpha1-compatible-14a8b92"
          , arch = Arch.Type.Amd64
          , if_ = None B/If
          }
      }

let debLabelSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion} ${Profiles.toSuffixUppercase
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

let buildDebian
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
                        ]
                      # BuildFlags.buildEnvs spec.buildFlags
                      # spec.extraBuildEnvs
                    )
                    "${spec.buildScript} ${Artifacts.toDebianNames
                                             spec.artifacts
                                             spec.network
                                             spec.profile}"
                # [ Cmd.run
                      "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                        spec.debVersion}"
                  ]
            , label = "Debian: Build ${debLabelSuffix spec}"
            , key = "build-deb-pkg${Optional/default Text "" spec.suffix}"
            , target = Size.XLarge
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
                  , profile = spec.profile
                  , build_flag = spec.buildFlags
                  , step = step_dep_name
                  , prefix = spec.prefix
                  , arch = spec.arch
                  }

          let docker_publish = DockerPublish.Type.Essential

          let base_dep = \(artifact_param: Artifacts.Type) ->
                DockerVersion.dependsOn
                  DockerVersion.DepsSpec::{,
                    codename = DockerVersion.ofDebian spec.debVersion
                    , network = Network.Type.Base
                    , profile = spec.profile
                    , artifact = artifact_param
                    } 

          let deps_or_base = \(artifact_param: Artifacts.Type) ->
                    merge
                      { Base = deps
                      , Devnet = base_dep artifact_param
                      , Mainnet = base_dep artifact_param
                      , Legacy = base_dep artifact_param
                      }
                      spec.network
                      
          in  merge
                { Daemon =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps_or_base Artifacts.Type.Daemon
                    , service = Artifacts.Type.Daemon
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , verify = True
                    , arch = spec.arch
                    , if_ = spec.if_
                    } ]
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
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
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
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
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
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    }
                  ]
                , Archive =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps_or_base Artifacts.Type.Archive
                    , service = Artifacts.Type.Archive
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , verify = True
                    , arch = spec.arch
                    , if_ = spec.if_
                    }
                  ]
                , Rosetta =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps_or_base Artifacts.Type.Rosetta
                    , service = Artifacts.Type.Rosetta
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_legacy_version = spec.deb_legacy_version
                    , verify = True
                    , arch = spec.arch
                    , if_ = spec.if_
                    }
                  ]
                , ZkappTestTransaction =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.ZkappTestTransaction
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , deb_codename = spec.debVersion
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    }
                  ]
                , FunctionalTestSuite =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.FunctionalTestSuite
                    , network = Network.Type.Base
                    , deb_codename = spec.debVersion
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
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
            }
          , steps = steps
          }

let buildDebians : MinaBuildSpec.Type -> List Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  merge
            { Base = [ buildDebian spec ]
            , Devnet = [] : List Command.Type
            , Mainnet = [] : List Command.Type
            , Legacy = [] : List Command.Type
            }
            spec.network

let onlyDebianPipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder spec (buildDebians spec)

let pipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder spec (buildDebians spec # docker_commands spec)

in  { pipeline = pipeline
    , onlyDebianPipeline = onlyDebianPipeline
    , MinaBuildSpec = MinaBuildSpec
    , buildDebian = buildDebian
    }
