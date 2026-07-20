let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Dockers = ../../Constants/Docker/Versions.dhall

let Docker = ../../Constants/Docker/Package.dhall

let Network = ../../Constants/Network.dhall

let network = Network.Type.Devnet

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/AutoHardforkTest" "dhall"
      , S.exactly_noext "dockerfiles/Dockerfile-mina-daemon-auto-hardfork"
      , S.exactly "scripts/hardfork/dispatcher" "sh"
      , S.exactly "scripts/hardfork/create_runtime_config" "sh"
      , S.exactly "buildkite/scripts/tests/hardfork/dispatcher-tests" "sh"
      , S.exactly
          "buildkite/scripts/tests/hardfork/create-runtime-config-tests"
          "sh"
      , S.exactly "scripts/docker/build" "sh"
      , S.exactly "scripts/debian/builder-helpers" "sh"
      ]

let hardforkDocker =
      Docker.fullDockerTag
        Docker.Tag::{
        , package = Docker.Type.DaemonAutoHardfork { network = network }
        , network = network
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "AutoHardforkTest"
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
                  "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh"
              , Cmd.run
                  "buildkite/scripts/tests/hardfork/dispatcher-tests.sh --docker ${hardforkDocker}"
              ]
            , label = "Auto Hardfork: Dispatcher Tests"
            , key = "auto-hardfork-dispatcher-tests-bullseye"
            , target = Size.Small
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            , depends_on =
                Dockers.dependsOn
                  Dockers.DepsSpec::{
                  , codename = Dockers.Type.Bullseye
                  , artifact =
                      Docker.Type.DaemonAutoHardfork { network = network }
                  , network = network
                  }
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "buildkite/scripts/tests/hardfork/create-runtime-config-tests.sh"
              ]
            , label = "Auto Hardfork: create_runtime_config Tests"
            , key = "auto-hardfork-create-runtime-config-tests"
            , target = Size.Small
            }
        ]
      }
