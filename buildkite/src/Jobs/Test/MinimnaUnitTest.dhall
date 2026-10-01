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
          [ S.contains "src/app/minimina"
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/MinimnaUnitTest")
          ]
        , path = "Test"
        , name = "MinimnaUnitTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInDefaultToolchain
                  ([] : List Text)
                  "cd src/app/minimina && PATH=/home/opam/.cargo/bin:\$PATH cargo test"
            , label = "Minimina unit tests"
            , key = "minimina-unit-test"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
