let Cmd = ../Lib/Cmds.dhall

let B = ../External/Buildkite.dhall

let S = ../Lib/SelectFiles.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ../Command/Base.dhall

let Size = ../Command/Size.dhall

let Network = ../Constants/Network.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Dockers = ../Constants/DockerVersions.dhall

let Profiles = ../Constants/Profiles.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let B/If = B.definitions/commandStep/properties/if/Type

let Spec =
      { Type =
          { dockerType : Dockers.Type
          , network : Network.Type
          , softFail : B/SoftFail
          , timeout : Natural
          , profile : Profiles.Type
          , scope : List PipelineScope.Type
          , repo : DockerRepo.Type
          , if_ : B/If
          }
      , default =
          { dockerType = Dockers.Type.Bullseye
          , network = Network.Type.Devnet
          , softFail = B/SoftFail.Boolean False
          , timeout = 1500
          , profile = Profiles.Type.Devnet
          , scope = PipelineScope.Full
          , repo = DockerRepo.Type.InternalEurope
          , if_ =
              "build.pull_request.base_branch != \"develop\" && build.branch != \"develop\""
          }
      }

let command
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                [ Cmd.chain
                    [ "export MINA_DEB_CODENAME=${Dockers.lowerName
                                                    spec.dockerType}"
                    , "source ./buildkite/scripts/export-git-env-vars.sh"
                    , "scripts/tests/daemon-docker-sync.sh --network ${Network.lowerName
                                                                         spec.network} --tag \\\${MINA_DOCKER_TAG}-${Network.lowerName
                                                                                                                       spec.network} --timeout ${Natural/show
                                                                                                                                                   spec.timeout} --repo ${DockerRepo.show
                                                                                                                                                                            spec.repo}"
                    ]
                ]
            , label =
                "Daemon docker sync ${Network.lowerName spec.network} test"
            , key =
                "daemon-docker-sync-${Network.lowerName spec.network}-test"
            , target = Size.XLarge
            , artifact_paths = [ S.contains "test_output/artifacts/**/*" ]
            , soft_fail = Some spec.softFail
            , if_ = Some spec.if_
            , depends_on =
                Dockers.dependsOn
                  Dockers.DepsSpec::{
                  , codename = spec.dockerType
                  , network = spec.network
                  , artifact = Artifacts.Type.Daemon
                  , profile = spec.profile
                  }
            }

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.exactly
                    "buildkite/src/Jobs/Test/DaemonDockerSync${Network.capitalName
                                                                  spec.network}"
                    "dhall"
                , S.exactly
                    "buildkite/src/Command/DaemonDockerSync"
                    "dhall"
                , S.exactly "scripts/tests/daemon-docker-sync" "sh"
                ]
            , path = "Test"
            , name =
                "DaemonDockerSync${Network.capitalName spec.network}"
            , scope = spec.scope
            , tags =
              [ PipelineTag.Type.Long
              , PipelineTag.Type.Test
              , PipelineTag.Type.Stable
              ]
            }
          , steps = [ command spec ]
          }

in  { command = command, pipeline = pipeline, Spec = Spec }
