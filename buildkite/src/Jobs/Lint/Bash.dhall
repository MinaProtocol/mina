let B = ../../External/Buildkite.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

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
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  (     "sudo apt-get update"
                    ++  " && sudo apt-get install shellcheck"
                    ++  " && make check-bash "
                  )
            , label = "Bash: shellcheck"
            , key = "check-bash"
            , target = Size.Multi
            , soft_fail = Some (B/SoftFail.Boolean True)
            , docker = None Docker.Type
            }
        ]
      }
