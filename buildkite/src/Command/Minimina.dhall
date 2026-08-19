-- Builds the minimina cargo + debian package step (amd64).

let Command = ./Base.dhall

let Docker = ./Docker/Type.dhall

let Size = ./Size.dhall

let RunInToolchain = ./RunInToolchain.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let B = ../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let script =
          "PATH=/home/opam/.cargo/bin:\$PATH cargo build --release --manifest-path src/app/minimina/Cargo.toml"
      ++  " && ./buildkite/scripts/cache/manager.sh write-to-dir src/app/minimina/target/release/minimina minimina-amd64"
      ++  " && mkdir -p _build"
      ++  " && MINA_DEB_CODENAME=noble ./scripts/debian/build.sh minimina"
      ++  " && ./buildkite/scripts/cache/manager.sh write-to-dir '_build/minimina_*.deb' debians/noble/"

let buildStep
    : Optional B/SoftFail -> Command.Type
    =     \(soft_fail : Optional B/SoftFail)
      ->  Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  RunInToolchain.Config::{
                  , image = ContainerImages.minaToolchainNoble.amd64
                  , environment = [ "ARCHITECTURE=amd64" ]
                  , innerScript = script
                  }
            , label = "Build minimina (amd64)"
            , key = "build-minimina-amd64"
            , target = Size.Small
            , docker = None Docker.Type
            , soft_fail = soft_fail
            }

in  { buildStep = buildStep }
