let B = ../../External/Buildkite.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let B/SoftFail/ExitStatus =
      B.definitions/commandStep/properties/soft_fail/union/properties/exit_status/Type

let buildTestCmd
    : Text -> Text -> Size -> Command.Type
    = \(profile : Text) ->
      \(path : Text) ->
      \(cmd_target : Size) ->
        let command_key = "failing-unit-test-${profile}"

        in  Command.build
              Command.Config::{
              , commands =
                  RunInToolchain.runInToolchain
                    [ "DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN" ]
                    "buildkite/scripts/unit-test.sh ${profile} ${path} && buildkite/scripts/upload-partial-coverage-data.sh ${command_key} dev"
              , label = "${profile} must fail unit test"
              , key = command_key
              , target = cmd_target
              , docker = None Docker.Type
              , retries =
                [ Command.Retry::{
                  , exit_status = Command.ExitStatus.Code +0
                  , limit = Some 1
                  }
                ]
              , soft_fail = Some
                  ( B/SoftFail.ListSoft_fail/Type
                      [ { exit_status = Some (B/SoftFail/ExitStatus.Number 1) }
                      ]
                  )
              , artifact_paths = [ S.contains "core_dumps/*" ]
              }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let unitDirtyWhen =
                [ S.strictlyStart (S.contains "src/test/failing_unit_test")
                , S.strictlyStart (S.contains "buildkite")
                ]

          in  JobSpec::{
              , dirtyWhen = unitDirtyWhen
              , path = "Test"
              , name = "MustFailUnitTest"
              , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
              }
      , steps = [ buildTestCmd "dev" "src/test/failing_unit_test" Size.Small ]
      }
