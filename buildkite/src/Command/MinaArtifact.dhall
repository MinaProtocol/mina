let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let Libp2p = ./Libp2pHelperBuild.dhall

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
          , networks : List Network.Type
          , buildFlags : BuildFlags.Type
          , toolchainSelectMode : Toolchain.SelectionMode
          , mode : PipelineMode.Type
          , tags : List PipelineTag.Type
          , channel : DebianChannel.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = Artifacts.AllButTests
          , debVersion = DebianVersions.DebVersion.Bullseye
          , profile = Profiles.Type.Standard
          , buildFlags = BuildFlags.Type.None
          , networks = [ Network.Type.Berkeley ]
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebian
          , mode = PipelineMode.Type.PullRequest
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , channel = DebianChannel.Type.Unstable
          }
      }

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
                        , Network.foldMinaBuildMainnetEnv spec.networks
                        ]
                      # BuildFlags.buildEnvs spec.buildFlags
                    )
                    "./buildkite/scripts/build-release.sh ${Artifacts.toDebianNames
                                                              spec.artifacts
                                                              spec.networks}"
                # [ Cmd.run
                      "./buildkite/scripts/debian/upload-to-gs.sh ${DebianVersions.lowerName
                                                                      spec.debVersion}"
                  ]
            , label =
                "Build Mina for ${DebianVersions.capitalName
                                    spec.debVersion} ${Profiles.toSuffixUppercase
                                                         spec.profile} ${BuildFlags.toSuffixUppercase
                                                                           spec.buildFlags}"
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
                  spec.profile
                  spec.buildFlags
                  step_dep_name

          in  merge
                { Daemon =
                    Prelude.List.map
                      Network.Type
                      DockerImage.ReleaseSpec.Type
                      (     \(n : Network.Type)
                        ->  DockerImage.ReleaseSpec::{
                            , deps = deps
                            , service =
                                Artifacts.dockerName Artifacts.Type.Daemon
                            , network = Network.lowerName n
                            , deb_codename =
                                "${DebianVersions.lowerName spec.debVersion}"
                            , deb_profile = spec.profile
                            , build_flags = spec.buildFlags
                            , deb_repo = DebianRepo.Type.Local
                            , step_key =
                                "daemon-${Network.lowerName
                                            n}-${DebianVersions.lowerName
                                                   spec.debVersion}${Profiles.toLabelSegment
                                                                       spec.profile}${BuildFlags.toLabelSegment
                                                                                        spec.buildFlags}-docker-image"
                            }
                      )
                      spec.networks
                , TestExecutive = [] : List DockerImage.ReleaseSpec.Type
                , LogProc = [] : List DockerImage.ReleaseSpec.Type
                , BatchTxn =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = "mina-batch-txn"
                    , network = "berkeley"
                    , deb_codename =
                        "${DebianVersions.lowerName spec.debVersion}"
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , step_key =
                        "batch-txn-${DebianVersions.lowerName
                                       spec.debVersion}${BuildFlags.toLabelSegment
                                                           spec.buildFlags}--docker-image"
                    }
                  ]
                , Archive =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = "mina-archive"
                    , deb_codename =
                        "${DebianVersions.lowerName spec.debVersion}"
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , step_key =
                        "archive-${DebianVersions.lowerName
                                     spec.debVersion}${Profiles.toLabelSegment
                                                         spec.profile}${BuildFlags.toLabelSegment
                                                                          spec.buildFlags}-docker-image"
                    }
                  ]
                , Rosetta =
                    Prelude.List.map
                      Network.Type
                      DockerImage.ReleaseSpec.Type
                      (     \(n : Network.Type)
                        ->  DockerImage.ReleaseSpec::{
                            , deps = deps
                            , service =
                                Artifacts.dockerName Artifacts.Type.Rosetta
                            , network = Network.lowerName n
                            , deb_codename =
                                "${DebianVersions.lowerName spec.debVersion}"
                            , deb_profile = spec.profile
                            , build_flags = spec.buildFlags
                            , deb_repo = DebianRepo.Type.Local
                            , step_key =
                                "rosetta-${Network.lowerName
                                             n}-${DebianVersions.lowerName
                                                    spec.debVersion}${BuildFlags.toLabelSegment
                                                                        spec.buildFlags}-docker-image"
                            }
                      )
                      spec.networks
                , ZkappTestTransaction =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = "mina-zkapp-test-transaction"
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , deb_codename =
                        "${DebianVersions.lowerName spec.debVersion}"
                    , step_key =
                        "zkapp-test-transaction-${DebianVersions.lowerName
                                                    spec.debVersion}${Profiles.toLabelSegment
                                                                        spec.profile}${BuildFlags.toLabelSegment
                                                                                         spec.buildFlags}--docker-image"
                    }
                  ]
                , FunctionalTestSuite =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = "mina-test-suite"
                    , deb_codename =
                        "${DebianVersions.lowerName spec.debVersion}"
                    , build_flags = spec.buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , step_key =
                        "test-suite-${DebianVersions.lowerName
                                        spec.debVersion}${Profiles.toLabelSegment
                                                            spec.profile}${BuildFlags.toLabelSegment
                                                                             spec.buildFlags}--docker-image"
                    , network = "berkeley"
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
            , name =
                "${spec.prefix}${DebianVersions.capitalName
                                   spec.debVersion}${Profiles.toSuffixUppercase
                                                       spec.profile}${BuildFlags.toSuffixUppercase
                                                                        spec.buildFlags}"
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
            [ Libp2p.step spec.debVersion spec.buildFlags
            , build_artifacts spec
            , publish_to_debian_repo
                spec
                ( DebianVersions.dependsOnStep
                    (Some spec.prefix)
                    spec.debVersion
                    spec.profile
                    spec.buildFlags
                    "build"
                )
            ]

let pipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  pipelineBuilder
            spec
            (   [ Libp2p.step spec.debVersion spec.buildFlags
                , build_artifacts spec
                ]
              # docker_commands spec
            )

in  { pipeline = pipeline
    , onlyDebianPipeline = onlyDebianPipeline
    , publishToDebian = publish_to_debian_repo
    , MinaBuildSpec = MinaBuildSpec
    }
