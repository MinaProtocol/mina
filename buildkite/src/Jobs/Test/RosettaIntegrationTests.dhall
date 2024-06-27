let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Profiles = ../../Constants/Profiles.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/RosettaIntegrationTests" "dhall"
      , S.exactly "buildkite/scripts/rosetta-integration-tests" "sh"
      , S.exactly "buildkite/scripts/rosetta-integration-tests-fast" "sh"
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "RosettaIntegrationTests"
        , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
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
                      "gcr.io/o1labs-192920/mina-rosetta:\\\${MINA_DOCKER_TAG}"
                  }
                  "buildkite/scripts/rosetta-integration-tests-fast.sh"
              ]
            , label = "Rosetta integration tests Bullseye"
            , key = "rosetta-integration-tests-bullseye"
            , target = Size.Small
            , depends_on =
                Dockers.dependsOn
                  Dockers.Type.Bullseye
                  Profiles.Type.Standard
                  "rosetta"
            }
        ]
      }
