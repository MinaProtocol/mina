let Prelude = ../../External/Prelude.dhall

let Decorate = ../../Lib/Decorate.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let opamCommands =
  [
    "cat scripts/setup-opam.sh > opam_ci_cache.sig",
    "cat src/opam.export >> opam_ci_cache.sig",
    "date +%Y-%m >> opam_ci_cache.sig",
    "make setup-opam"
-- TODO: Artifact caching
  ]

let commands =
  opamCommands # [
    "make check-snarky-submodule"
  ]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = Decorate.decorateAll commands,
        label = "Build client-sdk",
        key = "build-client-sdk",
        target = Size.Small,
        docker = Docker::{ image = (../../Constants/ContainerImages.dhall).codaToolchain }
      }
    ]
  }

