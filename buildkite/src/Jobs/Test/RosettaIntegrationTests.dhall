let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Network = ../../Constants/Network.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let network = Network.Type.Berkeley

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/RosettaIntegrationTests" "dhall"
      , S.exactly "buildkite/scripts/rosetta-integration-tests" "sh"
      , S.exactly "buildkite/scripts/rosetta-integration-tests-fast" "sh"
      ]

let rosettaDocker =
      Artifacts.fullDockerTag
        Artifacts.Tag::{ artifact = Artifacts.Type.Rosetta, network = network }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "RosettaIntegrationTests"
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
              , RunWithPostgres.runInDockerWithPostgresConn
                  ([] : List Text)
                  rosettaDocker
                  "./buildkite/scripts/rosetta-indexer-test.sh"
              , Cmd.runInDocker
                  Cmd.Docker::{ image = rosettaDocker }
                  "buildkite/scripts/rosetta-integration-tests-fast.sh"
              ]
            , label = "Rosetta integration tests Bullseye"
            , key = "rosetta-integration-tests-bullseye"
            , target = Size.Small
            , depends_on =
                Dockers.dependsOn
                  Dockers.DepsSpec::{
                  , codename = Dockers.Type.Bullseye
                  , artifact = Artifacts.Type.Rosetta
                  , network = network
                  }
            }
        ]
      }
