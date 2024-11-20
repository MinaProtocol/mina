let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let level = "warning"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "buildkite/scripts"
          , S.contains "scripts"
          , S.exactly "buildkite/src/Jobs/Lint/Bash" "dhall"
          ]
        , path = "Lint"
        , name = "Bash"
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
                RunInToolchain.runInToolchainBullseye
                  ([] : List Text)
                  (     "sudo apt-get install shellcheck"
                    ++  " && shellcheck scripts/**/*.sh -S ${level} "
                    ++  " && shellcheck buildkite/scripts/**/*.sh -S ${level} "
                  )
            , label = "Bash: shellcheck"
            , key = "check-bash"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
