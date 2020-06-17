let Prelude = ../../../External/Prelude.dhall

let Cmd = ../../../Lib/Cmds.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let Command/Coda = ../../../Command/Coda.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall

let commands =
  [
    Cmd.run "eval $$(opam config env) && make check-format",
    Cmd.run "./scripts/require-ppx-version.py"
  ]
in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command/Coda.build
        Command/Coda.Config::{
          commands = commands,
          label = "OCaml Lints; Check-format, Require-ppx-version",
          key = "check"
        }
    ]
  }
