let Prelude = ../../../External/Prelude.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let Command = ../../../Command/Base.dhall
let Command/Decorate = ../../../Command/Decorate.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

let commands =
  [
    "./scripts/lint_codeowners.sh",
    "./scripts/lint_rfcs.sh",
    "make check-snarky-submodule",
    "./scripts/lint_preprocessor_deps.sh"
  ]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command.Config::{
        commands = Command/Decorate.decorateAll commands,
        label = "Fast lint steps; CODEOWNERs, RFCs, Check Snarky Submodule, Preprocessor Deps",
        key = "lint",
        target = Size.Small,
        docker = Docker::{ image = (../../../Constants/ContainerImages.dhall).toolchainBase }
      }
    ]
  }

