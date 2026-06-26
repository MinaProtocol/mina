-- Fast unit tests for the mina-bootstrap Go CLI (src/app/bootstrap).
--
-- Runs `go vet` + `go test ./...` (untagged tests only) on every PR that
-- touches the bootstrap tool. The heavier `integration`-tagged end-to-end test
-- (Postgres + restored dump + mina-archive-blocks) lives in the separate,
-- manually-triggered MinaBootstrapCatchupIntegrationTest job.

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/bootstrap")
          , S.exactly "scripts/ensure-go" "sh"
          , S.exactly "buildkite/scripts/tests/mina-bootstrap-unit-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/MinaBootstrapUnitTest" "dhall"
          ]
        , path = "Test"
        , name = "MinaBootstrapUnitTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{ image = ContainerImages.minaToolchain }
                  "./buildkite/scripts/tests/mina-bootstrap-unit-test.sh"
              ]
            , label = "mina-bootstrap unit tests"
            , key = "mina-bootstrap-unit-tests"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
