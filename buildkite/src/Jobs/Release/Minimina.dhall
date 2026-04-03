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
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/Minimina")
          ]
        , path = "Release"
        , name = "Minimina"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Release
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "PATH=/home/opam/.cargo/bin:\$PATH cargo build --release --manifest-path src/app/minimina/Cargo.toml && ./buildkite/scripts/cache/manager.sh write-to-dir src/app/minimina/target/release/minimina minimina"
            , label = "Build minimina"
            , key = "build-minimina"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
