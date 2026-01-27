let Cmd = ../../Lib/Cmds.dhall

let B = ../../External/Buildkite.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Network = ../../Constants/Network.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let B/If = B.definitions/commandStep/properties/if/Type

let Spec =
      { Type =
          { dockerType : Dockers.Type
          , network : Network.Type
          , additionalDirtyWhen : List S.Type
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
          , additionalDirtyWhen = [] : List S.Type
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
                  , "scripts/tests/rosetta-connectivity.sh --network ${Network.lowerName
                                                                         spec.network} --tag \\\${MINA_DOCKER_TAG} --timeout ${Natural/show
                                                                                                                                 spec.timeout} --repo ${DockerRepo.show
                                                                                                                                                          spec.repo} --run-compatibility-test develop --run-load-test "
                  ]
              ]
            , label =
                "Rosetta ${Network.lowerName spec.network} connectivity test "
            , key =
                "rosetta-${Network.lowerName spec.network}-connectivity-test"
            , target = Size.XLarge
            , artifact_paths = [ S.contains "test_output/artifacts/**/*" ]
            , soft_fail = Some spec.softFail
            , if_ = Some spec.if_
            , depends_on =
                Dockers.dependsOn
                  Dockers.DepsSpec::{
                  , codename = spec.dockerType
                  , network = spec.network
                  , artifact = Artifacts.Type.Rosetta
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
                      "buildkite/src/Jobs/Test/RosettaIntegrationTests"
                      "dhall"
                  , S.exactly
                      "buildkite/src/Jobs/Test/Rosetta${Network.capitalName
                                                          spec.network}Connect"
                      "dhall"
                  , S.exactly
                      "buildkite/src/Command/Rosetta/Connectivity"
                      "dhall"
                  , S.exactly "scripts/tests/rosetta-connectivity" "sh"
                  , S.exactly
                      "buildkite/scripts/tests/rosetta-integration-tests"
                      "sh"
                  ]
                # spec.additionalDirtyWhen
            , path = "Test"
            , name = "Rosetta${Network.capitalName spec.network}Connect"
            , scope = spec.scope
            , tags =
              [ PipelineTag.Type.Long
              , PipelineTag.Type.Test
              , PipelineTag.Type.Stable
              , PipelineTag.Type.Rosetta
              ]
            }
          , steps = [ command spec ]
          }

in  { command = command, pipeline = pipeline, Spec = Spec }
