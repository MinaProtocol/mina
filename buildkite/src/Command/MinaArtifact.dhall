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
                      "./buildkite/scripts/upload-deb-to-gs.sh ${DebianVersions.lowerName
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

let docker_step
    :     Artifacts.Type
      ->  DebianVersions.DebVersion
      ->  List Network.Type
      ->  Profiles.Type
      ->  BuildFlags.Type
      ->  List DockerImage.ReleaseSpec.Type
    =     \(artifact : Artifacts.Type)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(networks : List Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(buildFlags : BuildFlags.Type)
      ->  let step_dep_name = "build"

          let deps =
                DebianVersions.dependsOnStep
                  debVersion
                  profile
                  buildFlags
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
                                "${DebianVersions.lowerName debVersion}"
                            , deb_profile = profile
                            , build_flags = buildFlags
                            , deb_repo = DebianRepo.Type.Local
                            , step_key =
                                "daemon-${Network.lowerName
                                            n}-${DebianVersions.lowerName
                                                   debVersion}${Profiles.toLabelSegment
                                                                  profile}${BuildFlags.toLabelSegment
                                                                              buildFlags}-docker-image"
                            }
                      )
                      networks
                , TestExecutive =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service =
                        Artifacts.dockerName Artifacts.Type.TestExecutive
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , deb_profile = profile
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , step_key =
                        "test-executive-${DebianVersions.lowerName
                                            debVersion}${BuildFlags.toLabelSegment
                                                           buildFlags}--docker-image"
                    }
                  ]
                , BatchTxn =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.dockerName Artifacts.Type.BatchTxn
                    , network = Network.lowerName Network.Type.Berkeley
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , deb_profile = profile
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , step_key =
                        "batch-txn-${DebianVersions.lowerName
                                       debVersion}${BuildFlags.toLabelSegment
                                                      buildFlags}--docker-image"
                    }
                  ]
                , Archive =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.dockerName Artifacts.Type.Archive
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , deb_profile = profile
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , step_key =
                        "archive-${DebianVersions.lowerName
                                     debVersion}${Profiles.toLabelSegment
                                                    profile}${BuildFlags.toLabelSegment
                                                                buildFlags}-docker-image"
                    }
                  ]
                , ArchiveMigration =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service =
                        Artifacts.dockerName Artifacts.Type.ArchiveMigration
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = profile
                    , step_key =
                        "archive-migration-${DebianVersions.lowerName
                                               debVersion}${BuildFlags.toLabelSegment
                                                              buildFlags}--docker-image"
                    }
                  ]
                , Rosetta =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.dockerName Artifacts.Type.Rosetta
                    , network = Network.lowerName Network.Type.Berkeley
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = profile
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , step_key =
                        "rosetta-${DebianVersions.lowerName
                                     debVersion}${BuildFlags.toLabelSegment
                                                    buildFlags}-docker-image"
                    }
                  ]
                , ZkappTestTransaction =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service =
                        Artifacts.dockerName Artifacts.Type.ZkappTestTransaction
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = profile
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , step_key =
                        "zkapp-test-transaction-${DebianVersions.lowerName
                                                    debVersion}${Profiles.toLabelSegment
                                                                   profile}${BuildFlags.toLabelSegment
                                                                               buildFlags}--docker-image"
                    }
                  ]
                , FunctionalTestSuite =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service =
                        Artifacts.dockerName Artifacts.Type.FunctionalTestSuite
                    , deb_codename = "${DebianVersions.lowerName debVersion}"
                    , build_flags = buildFlags
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = profile
                    , step_key =
                        "test-suite-${DebianVersions.lowerName
                                        debVersion}${Profiles.toLabelSegment
                                                       profile}${BuildFlags.toLabelSegment
                                                                   buildFlags}--docker-image"
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
                  (     \(artifact : Artifacts.Type)
                    ->  docker_step
                          artifact
                          spec.debVersion
                          spec.networks
                          spec.profile
                          spec.buildFlags
                  )
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

let pipeline
    : MinaBuildSpec.Type -> Pipeline.Config.Type
    =     \(spec : MinaBuildSpec.Type)
      ->  let steps =
                [ Libp2p.step spec.debVersion spec.buildFlags
                , build_artifacts spec
                ]

          in  Pipeline.Config::{
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
              , steps = steps # docker_commands spec
              }

in  { pipeline = pipeline, MinaBuildSpec = MinaBuildSpec }
