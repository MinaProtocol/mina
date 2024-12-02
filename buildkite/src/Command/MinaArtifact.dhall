let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let DockerImage = ./DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Toolchain = ../Constants/Toolchain.dhall

let MinaBuildSpec =
      { Type =
          { prefix : Text
          , artifacts : List Artifacts.Type
          , debVersion : DebianVersions.DebVersion
          , profile : Profiles.Type
          , network : Network.Type
          , buildFlags : BuildFlags.Type
          , toolchainSelectMode : Toolchain.SelectionMode
          , mode : PipelineMode.Type
          , tags : List PipelineTag.Type
          , channel : DebianChannel.Type
          , debianRepo : DebianRepo.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = Artifacts.AllButTests
          , debVersion = DebianVersions.DebVersion.Bullseye
          , profile = Profiles.Type.Standard
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Devnet
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebian
          , mode = PipelineMode.Type.PullRequest
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          }
      }

let labelSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion} ${Network.capitalName
                                    spec.network} ${Profiles.toSuffixUppercase
                                                      spec.profile} ${BuildFlags.toSuffixUppercase
                                                                        spec.buildFlags}"

let nameSuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion}${Network.capitalName
                                   spec.network}${Profiles.toSuffixUppercase
                                                    spec.profile}${BuildFlags.toSuffixUppercase
                                                                     spec.buildFlags}"

let keySuffix
    : MinaBuildSpec.Type -> Text
    =     \(spec : MinaBuildSpec.Type)
      ->  "${Profiles.toLabelSegment spec.profile}${BuildFlags.toLabelSegment
                                                      spec.buildFlags}"

let build_artifacts
    : MinaBuildSpec.Type -> Command.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  Toolchain.select
                    spec.toolchainSelectMode
                    spec.debVersion
                    (   [ "DUNE_PROFILE=${Profiles.duneProfile spec.profile}"
                        , "AWS_ACCESS_KEY_ID"
                        , "AWS_SECRET_ACCESS_KEY"
                        , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                        , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                        , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                 spec.debVersion}"
                        , Network.buildMainnetEnv spec.network
                        ]
                      # BuildFlags.buildEnvs spec.buildFlags
                    )
                    "./buildkite/scripts/build-release.sh ${Artifacts.toDebianNames
                                                              spec.artifacts
                                                              spec.network}"
                # [ Cmd.run
                      "./buildkite/scripts/debian/upload-to-gs.sh ${DebianVersions.lowerName
                                                                      spec.debVersion}"
                  ]
            , label = "Debian: Build ${labelSuffix spec}"
            , key = "build-deb-pkg"
            , target = Size.XLarge
            , retries =
              [ Command.Retry::{
                , exit_status = Command.ExitStatus.Code +2
                , limit = Some 2
                }
              ]
            }

let publish_to_debian_repo =
          \(spec : MinaBuildSpec.Type)
      ->  \(dependsOn : List Command.TaggedKey.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                Toolchain.select
                  spec.toolchainSelectMode
                  spec.debVersion
                  [ "AWS_ACCESS_KEY_ID"
                  , "AWS_SECRET_ACCESS_KEY"
                  , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                           spec.debVersion}"
                  , "MINA_DEB_RELEASE=${DebianChannel.lowerName spec.channel}"
                  , "${DebianRepo.keyIdEnv spec.debianRepo}"
                  , "${DebianRepo.bucketEnv spec.debianRepo}"
                  ]
                  "./buildkite/scripts/debian/publish.sh"
            , label =
                "Publish Mina for ${DebianVersions.capitalName
                                      spec.debVersion} ${Profiles.toSuffixUppercase
                                                           spec.profile}"
            , key =
                "publish-${DebianVersions.lowerName spec.debVersion}-deb-pkg"
            , depends_on = dependsOn
            , target = Size.Small
            }

let docker_step
    : Artifacts.Type -> MinaBuildSpec.Type -> List DockerImage.ReleaseSpec.Type
    =     \(artifact : Artifacts.Type)
      ->  \(spec : MinaBuildSpec.Type)
      ->  let step_dep_name = "build"

          let deps =
                DebianVersions.dependsOnStep
                  (Some spec.prefix)
                  spec.debVersion
                  spec.network
                  spec.profile
                  spec.buildFlags
                  step_dep_name

          in  merge
                { Daemon =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Daemon
                    , network = Network.lowerName spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    }
                  ]
                , TestExecutive = [] : List DockerImage.ReleaseSpec.Type
                , LogProc = [] : List DockerImage.ReleaseSpec.Type
                , Toolchain =
                  [ DockerImage.ReleaseSpec::{
                    , service = Artifacts.Type.Toolchain
                    , network = Network.lowerName Network.Type.Devnet
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    }
                  ]
                , ItnOrchestrator =
                  [ DockerImage.ReleaseSpec::{
                    , service = Artifacts.Type.ItnOrchestrator
                    , network = Network.lowerName Network.Type.Devnet
                    , deb_repo = DebianRepo.Type.Local
                    }
                  ]
                , Leaderboard =
                  [ DockerImage.ReleaseSpec::{
                    , service = Artifacts.Type.Leaderboard
                    }
                  ]
                , BatchTxn =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.BatchTxn
                    , network = Network.lowerName spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    }
                  ]
                , Archive =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Archive
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    }
                  ]
                , Rosetta =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Rosetta
                    , network = Network.lowerName spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , deb_repo = DebianRepo.Type.Local
                    }
                  ]
                , ZkappTestTransaction =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.ZkappTestTransaction
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , deb_codename = spec.debVersion
                    }
                  ]
                , FunctionalTestSuite =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.FunctionalTestSuite
                    , network = Network.lowerName Network.Type.Devnet
                    , deb_codename = spec.debVersion
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    }
                  ]
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
            , mode = spec.mode
            }
          , steps = steps
          }

let onlyDebianPipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder
            spec
            [ build_artifacts spec
            , publish_to_debian_repo
                spec
                ( DebianVersions.dependsOnStep
                    (Some spec.prefix)
                    spec.debVersion
                    spec.network
                    spec.profile
                    spec.buildFlags
                    "build"
                )
            ]

let pipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder spec ([ build_artifacts spec ] # docker_commands spec)

in  { pipeline = pipeline
    , onlyDebianPipeline = onlyDebianPipeline
    , publishToDebian = publish_to_debian_repo
    , MinaBuildSpec = MinaBuildSpec
    , labelSuffix = labelSuffix
    , keySuffix = keySuffix
    }
