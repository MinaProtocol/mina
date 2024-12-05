let Cmd = ../../Lib/Cmds.dhall

let B = ../../External/Buildkite.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Spec =
      { Type =
          { dockerType : Dockers.Type
          , network : Network.Type
          , mode : PipelineMode.Type
          , additionalDirtyWhen : List S.Type
          , softFail : B/SoftFail
          , timeout : Natural
          }
      , default =
          { dockerType = Dockers.Type.Bullseye
          , network = Network.Type.Berkeley
          , mode = PipelineMode.Type.PullRequest
          , additionalDirtyWhen = [] : List S.Type
          , softFail = B/SoftFail.Boolean False
          , timeout = 900
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
                                                                                                                                 spec.timeout}"
                  ]
              ]
            , label =
                "Rosetta ${Network.lowerName spec.network} connectivity test "
            , key =
                "rosetta-${Network.lowerName spec.network}-connectivity-test"
            , target = Size.XLarge
            , soft_fail = Some spec.softFail
            , depends_on =
                Dockers.dependsOnStep
                  spec.dockerType
                  "MinaArtifactMainnet"
                  (Some spec.network)
                  Profiles.Type.Standard
                  Artifacts.Type.Rosetta
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
                  , S.exactly "buildkite/scripts/rosetta-integration-tests" "sh"
                  , S.exactly
                      "buildkite/scripts/rosetta-integration-tests-full"
                      "sh"
                  ]
                # spec.additionalDirtyWhen
            , path = "Test"
            , name = "Rosetta${Network.capitalName spec.network}Connect"
            , mode = spec.mode
            , tags =
              [ PipelineTag.Type.Long
              , PipelineTag.Type.Test
              , PipelineTag.Type.Stable
              ]
            }
          , steps = [ command spec ]
          }

in  { command = command, pipeline = pipeline, Spec = Spec }
