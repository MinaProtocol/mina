let Prelude = ../../../External/Prelude.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let Command = ../../../Command/Base.dhall
let Command/Decorate = ../../../Command/Decorate.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall

let commands =
  [
    "sudo chown -R opam .",
    "eval $$(opam config env) && make check-format",
    "./scripts/require-ppx-version.py"
  ]
in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command.Config::{
        commands = Command/Decorate.decorateAll commands,
        label = "OCaml Lints; Check-format, Require-ppx-version",
        key = "check",
        target = Size.Large,
        docker = Docker::{ image = (../../../Constants/ContainerImages.dhall).codaToolchain }
      }
    ]
  }
