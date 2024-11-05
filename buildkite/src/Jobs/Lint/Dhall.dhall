let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let dump_pipelines_cmd =
      Cmd.runInDocker
        Cmd.Docker::{
        , image = (../../Constants/ContainerImages.dhall).toolchainBase
        }
        "buildkite/scripts/dhall/dump_dhall_to_pipelines.sh buildkite/src/Jobs _pipelines"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "buildkite/src", S.exactly "buildkite/Makefile" "" ]
        , path = "Lint"
        , name = "Dhall"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Lint
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make check_syntax" ]
            , label = "Dhall: syntax"
            , key = "check-dhall-syntax"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make check_lint" ]
            , label = "Dhall: lint"
            , key = "check-dhall-lint"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands = [ Cmd.run "cd buildkite && make check_format" ]
            , label = "Dhall: format"
            , key = "check-dhall-format"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../../Constants/ContainerImages.dhall).toolchainBase
              }
            }
        , Command.build
            Command.Config::{
            , commands =
                  [ dump_pipelines_cmd ]
                # RunInToolchain.runInToolchainBullseye
                    ([] : List Text)
                    "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines deps"
            , label = "Dhall: deps"
            , key = "check-dhall-deps"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        , Command.build
            Command.Config::{
            , commands =
                  [ dump_pipelines_cmd ]
                # RunInToolchain.runInToolchainBullseye
                    ([] : List Text)
                    "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines dirty-when  --repo ."
            , label = "Dhall: dirtyWhen"
            , key = "check-dhall-dirty"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        , Command.build
            Command.Config::{
            , commands =
                  [ dump_pipelines_cmd ]
                # RunInToolchain.runInToolchainBullseye
                    ([] : List Text)
                    "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines dups"
            , label = "Dhall: duplicates"
            , key = "check-dhall-dups"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        , Command.build
            Command.Config::{
            , commands =
                  [ dump_pipelines_cmd ]
                # RunInToolchain.runInToolchainBullseye
                    ([] : List Text)
                    "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines names"
            , label = "Dhall: job names"
            , key = "check-dhall-jobs"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
