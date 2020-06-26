let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ../Command/Base.dhall
let OpamInit = ../Command/OpamInit.dhall
let Docker = ../Command/Docker/Type.dhall
let Size = ../Command/Size.dhall

let buildTestCmd : Text -> Text -> Command.Type = \(profile : Text) -> \(path : Text) ->
  Command.build
    Command.Config::{
      commands =
        OpamInit.andThenRunInDocker (
          "source ~/.profile && make build && (dune runtest ${path} --profile=${profile} -j8" ++
          " || (./scripts/link-coredumps.sh && false))"
        ),
      label = "Run ${profile} unit-tests",
      key = "unit-test-${profile}",
      target = Size.XXlarge,
      docker = None Docker.Type
    }

in

Pipeline.build
  Pipeline.Config::{
    spec = 
      let unitDirtyWhen = [
        S.strictlyStart (S.contains "src/lib"),
        S.strictlyStart (S.contains "src/nonconsensus"),
        S.strictly (S.contains "Makefile"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Unit"),
        S.exactly "scripts/link-coredumps" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = unitDirtyWhen,
        name = "Unit"
      },
    steps = [
      buildTestCmd "dev" "src/lib",
      buildTestCmd "nonconsensus_medium_curves" "src/nonconsensus"
    ]
  }
