let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Size = ../../Command/Size.dhall

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [ S.contains "src/app/trace-tool", S.strictlyStart (S.contains "buildkite/src/Jobs/TraceTool") ],
      name = "TraceTool"
    },
    steps = [
    Command.build
      Command.Config::{
        commands = OpamInit.andThenRunInDocker
                        (([] : List Text))
                        ("cd src/app/trace-tool && cargo build --frozen")
        , label = "Build trace-tool"
        , key = "build-trace-tool"
        , target = Size.Medium
        , docker = None Docker.Type
      }
    ]
  }
