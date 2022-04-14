let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall
let DockerLogin = ../../Command/DockerLogin/Type.dhall


in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "dockerfiles/stages/1-"),
          S.strictlyStart (S.contains "dockerfiles/stages/2-"),
          S.strictlyStart (S.contains "dockerfiles/stages/3-"),
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaToolchainArtifact"),
          S.strictly (S.contains "src/opam.export")
        ],
        path = "Release",
        name = "MinaToolchainArtifact"
      },
    steps = [

      -- mina-toolchain Debian 12 "Bookworm" Toolchain
      let toolchainBullseyeSpec = DockerImage.ReleaseSpec::{
        service="mina-toolchain",
        deb_codename="bookworm",
        extra_args="--no-cache",
        step_key="toolchain-bookworm-docker-image"
      }

      in

      DockerImage.generateStep toolchainBookwormSpec,

      -- mina-toolchain Debian 11 "Bullseye" Toolchain
      let toolchainBullseyeSpec = DockerImage.ReleaseSpec::{
        service="mina-toolchain",
        deb_codename="bullseye",
        extra_args="--no-cache",
        step_key="toolchain-bullseye-docker-image"
      }

      in

      DockerImage.generateStep toolchainBullseyeSpec,

      -- mina-toolchain Debian 10 "Buster" Toolchain
      let toolchainBusterSpec = DockerImage.ReleaseSpec::{
        service="mina-toolchain",
        deb_codename="buster",
        extra_args="--no-cache",
        step_key="toolchain-buster-docker-image"
      }

      in

      DockerImage.generateStep toolchainBusterSpec,

      -- mina-toolchain Debian 9 "Stretch" Toolchain
      let toolchainStretchSpec = DockerImage.ReleaseSpec::{
        service="mina-toolchain",
        deb_codename="stretch",
        extra_args="--no-cache",
        step_key="toolchain-stretch-docker-image"
      }

      in

      DockerImage.generateStep toolchainStretchSpec

    ]
  }

