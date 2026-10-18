let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let dump_pipelines_cmd =
      Cmd.runInDocker
        Cmd.Docker::{ image = ContainerImages.toolchainBase }
        "buildkite/scripts/dhall/dump_dhall_to_pipelines.sh ./buildkite/src _pipelines"

let dhall_cmd =
      Cmd.runInDocker
        Cmd.Docker::{ image = ContainerImages.toolchainBase }
        "cd buildkite && make check_syntax check_lint check_format test_monorepo"

let checker_cmds =
          "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines deps && "
      ++  "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines dirty-when --repo . && "
      ++  "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines dups && "
      ++  "python3 ./buildkite/scripts/dhall/checker.py --root _pipelines names"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "buildkite/src"
          , S.exactly "buildkite/Makefile" ""
          , S.exactly "buildkite/scripts/monorepo" "sh"
          , S.exactly "buildkite/scripts/test_monorepo" "sh"
          ]
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
            , commands =
                  [ dump_pipelines_cmd, dhall_cmd ]
                # RunInToolchain.runInDefaultToolchain
                    ([] : List Text)
                    checker_cmds
            , label = "Dhall: checks"
            , key = "check-dhall"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
