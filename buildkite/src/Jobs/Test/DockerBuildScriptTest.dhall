let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "scripts/docker/build" "sh"
          , S.exactly "scripts/docker/helper" "sh"
          , S.strictlyStart (S.contains "scripts/docker/tests")
          , S.strictlyStart (S.contains "dockerfiles")
          , S.exactly "scripts/export-git-env-vars" "sh"
          , S.exactly "buildkite/scripts/export-git-env-vars" "sh"
          , S.strictlyStart (S.contains "buildkite/scripts/git-env")
          , S.exactly "scripts/tests/test_export_git_env_vars" "sh"
          , S.exactly "buildkite/src/Jobs/Test/DockerBuildScriptTest" "dhall"
          ]
        , path = "Test"
        , name = "DockerBuildScriptTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Docker
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = [ Cmd.run "./scripts/docker/tests/test_build.sh" ]
            , label = "Docker build script tests"
            , key = "docker-build-script-tests"
            , target = Size.Small
            , docker = None Docker.Type
            }
        , Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "./scripts/tests/test_export_git_env_vars.sh" ]
            , label = "Git env pin tests"
            , key = "git-env-pin-tests"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
