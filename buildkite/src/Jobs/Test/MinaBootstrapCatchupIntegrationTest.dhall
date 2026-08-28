-- End-to-end integration test for `mina-bootstrap catchup`.
--
-- Heavy, manually-triggered job: it restores a real archive dump, builds
-- mina-archive-blocks from source, backfills the forward diff from the live
-- precomputed-blocks bucket, and asserts no gap remains. Because it is gated to
-- the BootstrapRelease scope (NOT part of Scope.Full / ScopeFilter.All, same as
-- the bootstrap release pipeline), it runs ONLY when a pipeline is triggered
-- with the BootstrapOnly scope filter and the Bootstrap tag filter -- never on
-- PullRequest, Nightly, Weekly or Release.
--
-- Trigger:  ./buildkite/scripts/monorepo.sh --scopes bootstraprelease ...
--           (BUILDKITE_PIPELINE_SCOPE=BootstrapOnly, BUILDKITE_PIPELINE_FILTER=Bootstrap)

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/bootstrap")
          , S.strictlyStart (S.contains "src/app/archive_blocks")
          , S.exactly "buildkite/scripts/tests/mina-bootstrap-catchup-test" "sh"
          , S.exactly
              "buildkite/src/Jobs/Test/MinaBootstrapCatchupIntegrationTest"
              "dhall"
          ]
        , path = "Test"
        , name = "MinaBootstrapCatchupIntegrationTest"
        , scope = [ PipelineScope.Type.BootstrapRelease ]
        , tags =
          [ PipelineTag.Type.Bootstrap
          , PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Archive
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ RunWithPostgres.runInDockerWithPostgresConn
                  [ "NETWORK=mesa", "DUMP_DATE=2025-11-18", "DUMP_HOUR=1300" ]
                  (None RunWithPostgres.ScriptOrArchive)
                  ContainerImages.minaToolchain
                  "./buildkite/scripts/tests/mina-bootstrap-catchup-test.sh"
              ]
            , label = "mina-bootstrap catchup integration test"
            , key = "mina-bootstrap-catchup-it"
            , target = Size.XLarge
            }
        ]
      }
