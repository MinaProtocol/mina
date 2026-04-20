-- Builds the minimina cargo + debian package step for a given architecture.
-- Shared between Release/Minimina.dhall (amd64) and Release/MiniminaArm64.dhall
-- so both pipelines stay in lockstep when the build recipe changes.

let Command = ./Base.dhall

let Docker = ./Docker/Type.dhall

let Size = ./Size.dhall

let RunInToolchain = ./RunInToolchain.dhall

let Arch = ../Constants/Arch.dhall

let B = ../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let script =
          \(arch : Arch.Type)
      ->  let a = Arch.lowerName arch

          in      "PATH=/home/opam/.cargo/bin:\$PATH cargo build --release --manifest-path src/app/minimina/Cargo.toml"
              ++  " && ./buildkite/scripts/cache/manager.sh write-to-dir src/app/minimina/target/release/minimina minimina-${a}"
              ++  " && mkdir -p _build"
              ++  " && MINA_DEB_CODENAME=noble ./scripts/debian/build.sh minimina"
              ++  " && ./buildkite/scripts/cache/manager.sh write-to-dir '_build/minimina_*.deb' debians/noble/"

let size =
          \(arch : Arch.Type)
      ->  merge { Amd64 = Size.Small, Arm64 = Size.Arm64 } arch

let buildStep
    : Arch.Type -> Optional B/SoftFail -> Command.Type
    =     \(arch : Arch.Type)
      ->  \(soft_fail : Optional B/SoftFail)
      ->  let a = Arch.lowerName arch

          in  Command.build
                Command.Config::{
                , commands =
                    RunInToolchain.runInToolchainNoble
                      arch
                      [ "ARCHITECTURE=${a}" ]
                      (script arch)
                , label = "Build minimina (${a})"
                , key = "build-minimina-${a}"
                , target = size arch
                , docker = None Docker.Type
                , soft_fail = soft_fail
                }

in  { buildStep = buildStep }
