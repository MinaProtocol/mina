let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let jobDocker = Cmd.Docker::{image = (../../Constants/ContainerImages.dhall).rustToolchain}

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
            commands = [ Cmd.runInDocker jobDocker "cd src/app/trace-tool ; /home/opam/.cargo/bin/cargo check --frozen" ]
            , label = "Rust lint steps; trace-tool"
            , key = "lint-trace-tool"
            , target = Size.Medium
            , docker = None Docker.Type
          }
    ]
  }