let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Arch = ../../Constants/Arch.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

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
                RunInToolchain.runInToolchainNoble
                  Arch.Type.Amd64
                  ([] : List Text)
                  "PATH=/home/opam/.cargo/bin:\$PATH cargo build --release --manifest-path src/app/minimina/Cargo.toml && ./buildkite/scripts/cache/manager.sh write-to-dir src/app/minimina/target/release/minimina minimina-amd64 && mkdir -p _build && MINA_DEB_CODENAME=noble ./scripts/debian/build.sh minimina && ./buildkite/scripts/cache/manager.sh write-to-dir '_build/minimina_*.deb' debians/noble/"
            , label = "Build minimina (amd64)"
            , key = "build-minimina-amd64"
            , target = Size.Small
            , docker = None Docker.Type
            }
        , Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchainNoble
                  Arch.Type.Arm64
                  [ "ARCHITECTURE=arm64" ]
                  "PATH=/home/opam/.cargo/bin:\$PATH cargo build --release --manifest-path src/app/minimina/Cargo.toml && ./buildkite/scripts/cache/manager.sh write-to-dir src/app/minimina/target/release/minimina minimina-arm64 && mkdir -p _build && MINA_DEB_CODENAME=noble ./scripts/debian/build.sh minimina && ./buildkite/scripts/cache/manager.sh write-to-dir '_build/minimina_*.deb' debians/noble/"
            , label = "Build minimina (arm64)"
            , key = "build-minimina-arm64"
            , target = Size.Arm64
            , docker = None Docker.Type
            , soft_fail = Some (B/SoftFail.Boolean True)
            }
        ]
      }
