let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "src/app/trace-tool"
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/Rust")
          ]
        , path = "Lint"
        , name = "Rust"
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
                  "cd src/app/trace-tool ; PATH=/home/opam/.cargo/bin:\$PATH cargo check"
            , label = "Rust lint steps; trace-tool"
            , key = "lint-trace-tool"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
