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
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/TraceTool")
          ]
        , path = "Release"
        , name = "TraceTool"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Release ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "cd src/app/trace-tool && PATH=/home/opam/.cargo/bin:\$PATH cargo build --release"
            , label = "Build trace-tool"
            , key = "build-trace-tool"
            , target = Size.Small
            , docker = None Docker.Type
            , artifact_paths =
              [ S.contains "src/app/trace-tool/target/release/trace-tool" ]
            }
        ]
      }
