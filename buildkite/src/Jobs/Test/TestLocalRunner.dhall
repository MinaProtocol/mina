-- Validate that buildkite/local/run_job.sh works correctly.
--
-- Step 1 generates pipeline YAMLs inside Docker (dhall-to-yaml lives there).
-- Step 2 runs run_job.sh on the host in list / list-steps / dry-run modes
-- to exercise the full script without actually executing build commands.

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let jobName = "TestLocalRunner"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "buildkite/local", S.contains "buildkite/src" ]
        , path = "Test"
        , name = jobName
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "./buildkite/local/run_job.sh --skip-sync ZkappsExamplesTest"
              ]
            , label = "Test Local Bk Runner"
            , key = "test-local-run-job"
            , target = Size.Multi
            }
        ]
      }
