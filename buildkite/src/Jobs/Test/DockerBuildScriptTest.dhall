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
          , S.exactly "scripts/export-git-env-vars" "sh"
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
        ]
      }
