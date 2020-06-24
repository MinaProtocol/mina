let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command/Coda = ../../Command/Coda.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let commands =
  [
    Cmd.run "eval $$(opam config env) && make check-format",
    Cmd.run "./scripts/require-ppx-version.py"
  ]
in

Pipeline.build
  Pipeline.Config::{
    spec = 
      let 
          dirtyDhallDir = S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/OCaml")
      let 
          dirtyDhallDirCompiles = assert : S.compile [dirtyDhallDir] === "^buildkite/src/Jobs/Lint/OCaml"
      in
      JobSpec::{
        dirtyWhen = [
          dirtyDhallDir,
          S.strictlyStart (S.contains "src/")
        ],
        path = "Lint",
        name = "OCaml"
      },
    steps = [
      Command/Coda.build
        Command/Coda.Config::{
          commands = commands,
          label = "OCaml Lints; Check-format, Require-ppx-version",
          key = "check"
        }
    ]
  }
