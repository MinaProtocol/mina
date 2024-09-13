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

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/RosettaIntegrationTests" "dhall"
      , S.exactly "buildkite/scripts/rosetta-integration-tests" "sh"
      , S.exactly "buildkite/scripts/rosetta-integration-tests-full" "sh"
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "RosettaIntegrationTestsLong"
        , mode = PipelineMode.Type.Stable
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && echo \\\${MINA_DOCKER_TAG}"
              , Cmd.runInDocker
                  Cmd.Docker::{
                  , image =
                      "gcr.io/o1labs-192920/mina-rosetta:\\\${MINA_DOCKER_TAG}-berkeley"
                  }
                  "buildkite/scripts/rosetta-integration-tests-full.sh"
              ]
            , label = "Rosetta integration tests Bullseye Long"
            , key = "rosetta-integration-tests-bullseye-long"
            , soft_fail = Some (B/SoftFail.Boolean True)
            , target = Size.Small
            , depends_on =
                Dockers.dependsOn
                  Dockers.Type.Bullseye
                  (None Network.Type)
                  Profiles.Type.Standard
                  Artifacts.Type.Rosetta
            }
        ]
      }
