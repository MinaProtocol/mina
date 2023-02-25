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
          S.strictly (S.contains "opam.export"),
          -- Rust version has changed
          S.strictlyEnd (S.contains "rust-toolchain.toml")
        ],
        path = "Release",
        name = "MinaToolchainArtifact"
      },
    steps = [

      -- mina-toolchain Debian 11 "Bullseye" Toolchain
      let toolchainBullseyeSpec = DockerImage.ReleaseSpec::{
        service="mina-toolchain",
        deb_codename="bullseye",
        step_key="toolchain-bullseye",
        version="bullseye-\\\${BUILDKITE_COMMIT}"
      }

      in

      DockerImage.generateStep toolchainBullseyeSpec,

      -- mina-opam-deps Debian 11 "Bullseye" Opam Deps
      let opamBullseyeSpec = DockerImage.ReleaseSpec::{
        service="mina-opam-deps",
        deb_codename="bullseye",
        step_key="opam-bullseye",
        version="bullseye-\\\${BUILDKITE_COMMIT}"
      }

      in

      DockerImage.generateStep opamBullseyeSpec,

      -- mina-toolchain Debian 10 "Buster" Opam Deps
      let opamBusterSpec = DockerImage.ReleaseSpec::{
        service="mina-opam-deps",
        deb_codename="buster",
        step_key="opam-buster",
        version="buster-\\\${BUILDKITE_COMMIT}"
      }

      in

      DockerImage.generateStep opamBusterSpec,

      -- mina-opam-deps Debian 9 "Stretch" Opam Deps
      let opamStretchSpec = DockerImage.ReleaseSpec::{
        service="mina-opam-deps",
        deb_codename="stretch",
        step_key="opam-stretch",
        version="stretch-\\\${BUILDKITE_COMMIT}"
      }

      in

      DockerImage.generateStep opamStretchSpec,

      -- mina-toolchain Ubuntu 20.04 LTS "Focal" Fossa Opam Deps
      let opamFocalSpec = DockerImage.ReleaseSpec::{
        service="mina-opam-deps",
        deb_codename="focal",
        step_key="opam-focal",
        version="focal-\\\${BUILDKITE_COMMIT}"
      }

      in

      DockerImage.generateStep opamFocalSpec,

      -- mina-opam-deps Ubuntu 18.04 LTS "Bionic" Beaver Opam Deps
      let opamBionicSpec = DockerImage.ReleaseSpec::{
        service="mina-opam-deps",
        deb_codename="bionic",
        step_key="opam-bionic",
        version="bionic-\\\${BUILDKITE_COMMIT}"
      }

      in

      DockerImage.generateStep opamBionicSpec

    ]
  }

