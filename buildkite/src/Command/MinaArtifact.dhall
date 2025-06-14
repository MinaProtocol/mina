let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

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

let DockerPublish = ../Constants/DockerPublish.dhall

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
          , if : Optional B/If
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = Artifacts.AllButTests
          , debVersion = DebianVersions.DebVersion.Bullseye
          , profile = Profiles.Type.Standard
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Berkeley
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebian
          , mode = PipelineMode.Type.PullRequest
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          , if = None B/If
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
                      "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                        spec.debVersion}"
                  ]
            , label = "Debian: Build ${labelSuffix spec}"
            , key = "build-deb-pkg"
            , target = Size.XLarge
            , if = spec.if
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
                  (   [ "AWS_ACCESS_KEY_ID"
                      , "AWS_SECRET_ACCESS_KEY"
                      , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                               spec.debVersion}"
                      , "MINA_DEB_RELEASE=${DebianChannel.lowerName
                                              spec.channel}"
                      ]
                    # DebianRepo.keyIdEnvList spec.debianRepo
                    # DebianRepo.bucketEnvList spec.debianRepo
                  )
                  "./buildkite/scripts/debian/publish.sh"
            , label =
                "Publish Mina for ${DebianVersions.capitalName
                                      spec.debVersion} ${Profiles.toSuffixUppercase
                                                           spec.profile}"
            , key =
                "publish-${DebianVersions.lowerName spec.debVersion}-deb-pkg"
            , depends_on = dependsOn
            , target = Size.Small
            , if = spec.if
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

          let docker_publish = DockerPublish.Type.Essential

          in  merge
                { Daemon =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Daemon
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , if = spec.if
                    }
                  ]
                , TestExecutive = [] : List DockerImage.ReleaseSpec.Type
                , LogProc = [] : List DockerImage.ReleaseSpec.Type
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
                    , if = spec.if
                    }
                  ]
                , Archive =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Archive
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , if = spec.if
                    }
                  ]
                , Rosetta =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.Rosetta
                    , network = spec.network
                    , deb_codename = spec.debVersion
                    , deb_profile = spec.profile
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , if = spec.if
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
                    , if = spec.if
                    }
                  ]
                , FunctionalTestSuite =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Artifacts.Type.FunctionalTestSuite
                    , network = Network.Type.Berkeley
                    , deb_codename = spec.debVersion
                    , build_flags = spec.buildFlags
                    , docker_publish = docker_publish
                    , deb_repo = DebianRepo.Type.Local
                    , deb_profile = spec.profile
                    , if = spec.if
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
            , mode = spec.mode
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
    , publishToDebian = publish_to_debian_repo
    , MinaBuildSpec = MinaBuildSpec
    , labelSuffix = labelSuffix
    , keySuffix = keySuffix
    }
