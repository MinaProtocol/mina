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
          , S.contains "scripts/debian/builder-helpers.sh"
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
        , Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "mkdir -p _build && MINA_DEB_CODENAME=bullseye ./scripts/debian/build.sh minimina && ./buildkite/scripts/cache/manager.sh write-to-dir '_build/minimina_*.deb' debians/bullseye/"
            , label = "Build minimina debian package"
            , key = "build-minimina-deb"
            , target = Size.Small
            , docker = None Docker.Type
            , depends_on =
              [ { name = "Minimina", key = "build-minimina" } ]
            }
        ]
      }
