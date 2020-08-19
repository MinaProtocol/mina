let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [ S.contains "src/app/trace-tool", S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/Rust") ],
      path = "Lint",
      name = "Rust"
    },
    steps = [
        Command.build
          Command.Config::{
            commands = OpamInit.andThenRunInDocker
                            (([] : List Text))
                            ("cd src/app/trace-tool ; /home/opam/.cargo/bin/cargo check --frozen")
            , label = "Rust lint steps; trace-tool"
            , key = "lint-trace-tool"
            , target = Size.Medium
            , docker = None Docker.Type
          }
    ]
  }