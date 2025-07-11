let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let dirtyDhallDir =
                S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/Markdown")

          in  JobSpec::{
              , dirtyWhen =
                [ dirtyDhallDir, S.strictlyStart (S.contains "*.md") ]
              , path = "Lint"
              , name = "Markdown"
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
                  "npm install && make check-markdown"
            , label = "Check Markdown: Verify 80-character line wrapping"
            , key = "markdown-check"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }