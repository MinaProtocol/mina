let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let shellcheckVersion = "v0.10.0"

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
                    ++  " && wget https://github.com/koalaman/shellcheck/releases/download/${shellcheckVersion}/shellcheck-${shellcheckVersion}.linux.x86_64.tar.xz"
                    ++  " && tar xvf shellcheck-${shellcheckVersion}.linux.x86_64.tar.xz"
                    ++  " && sudo cp shellcheck-${shellcheckVersion}/shellcheck /usr/local/bin/"
                    ++  " && make check-bash"
                  )
            , label = "Bash: shellcheck"
            , key = "check-bash"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
