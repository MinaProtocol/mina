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

let network = Network.Type.Devnet

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/AutoHardforkTest" "dhall"
      , S.exactly "dockerfiles/Dockerfile-mina-daemon-auto-hardfork" ""
      , S.exactly "scripts/hardfork/dispatcher" "sh"
      , S.exactly "buildkite/scripts/tests/hardfork/dispatcher-tests" "sh"
      ]

let hardforkDocker =
      Artifacts.fullDockerTag
        Artifacts.Tag::{
        , artifact = Artifacts.Type.DaemonAutoHardfork
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
                  , artifact = Artifacts.Type.DaemonAutoHardfork
                  , network = network
                  }
            }
        ]
      }
