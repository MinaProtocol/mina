let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let buildTestCmd : Text -> Text -> Size -> Command.Type = \(profile : Text) -> \(path : Text) -> \(cmd_target : Size) ->
  let command_key = "unit-test-${profile}"
  in
  Command.build
    Command.Config::{
      commands = RunInToolchain.runInToolchain ["DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN"] "buildkite/scripts/unit-test.sh ${profile} ${path} && buildkite/scripts/upload-partial-coverage-data.sh ${command_key} dev",
      label = "${profile} unit-tests",
      key = command_key,
      target = cmd_target,
      docker = None Docker.Type,
      artifact_paths = [ S.contains "core_dumps/*" ],
      retry =
            Some {
                -- we only consider automatic retries
                automatic = Some (
                  -- and for every retry
                  let xs : List B/AutoRetryChunk =
                      List/map
                        Retry.Type
                        B/AutoRetryChunk
                        (\(retry : Retry.Type) ->
                        {
                          -- we always require the exit status
                          exit_status = Some (
                              merge
                                { Code = \(i : Integer) -> B/ExitStatus.Integer i
                                , Any = B/ExitStatus.String "*" }
                              retry.exit_status),
                          -- but limit is optional
                          limit =
                            Optional/map
                            Natural
                            Integer
                            Natural/toInteger
                            retry.limit
                      })
                      -- per https://buildkite.com/docs/agent/v3#exit-codes:
                      [
                        -- infra error
                        Retry::{ exit_status = ExitStatus.Code -1, limit = Some 4 },
                        -- infra error
                        Retry::{ exit_status = ExitStatus.Code +255, limit = Some 4 },
                        -- Git checkout error
                        Retry::{ exit_status = ExitStatus.Code +128, limit = Some 4 }
                      ]
                  in
                  B/Retry.ListAutomaticRetry/Type xs),
                manual = Some (B/Manual.Manual/Type {
                  allowed = Some True,
                  permit_on_passed = Some True,
                  reason = None Text
                })
            }
    }

in

Pipeline.build
  Pipeline.Config::{
    spec = 
      let unitDirtyWhen = [
        S.strictlyStart (S.contains "src/lib"),
        S.strictlyStart (S.contains "src/nonconsensus"),
        S.strictly (S.contains "Makefile"),
        S.exactly "buildkite/src/Jobs/Test/DaemonUnitTest" "dhall",
        S.exactly "scripts/link-coredumps" "sh",
        S.exactly "buildkite/scripts/unit-test" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = unitDirtyWhen,
        path = "Test",
        name = "DaemonUnitTest",
        tags = [ PipelineTag.Type.VeryLong, PipelineTag.Type.Test ]
      },
    steps = [
      buildTestCmd "dev" "src/lib" Size.XLarge
    ]
  }
