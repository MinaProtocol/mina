-- Runs test_executive on the native engine (host processes, no docker), so the
-- native path has CI coverage. One small lightnet test only: a full devnet
-- network does not fit in one agent.

let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let testName = "block-reward"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/src/Jobs/Test/NativeEngineTest" "dhall"
          , S.exactly "buildkite/scripts/run-test-executive-native" "sh"
          , S.strictlyStart (S.contains "buildkite/scripts/apps")
          ]
        , path = "Test"
        , name = "NativeEngineTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInDefaultToolchain
                  DebianVersions.overrideEnvs
                  "buildkite/scripts/run-test-executive-native.sh ${testName}"
            , artifact_paths = [ S.contains "${testName}*.native.test.log" ]
            , label = "${testName} integration test native"
            , key = "integration-test-${testName}-native"
            , target = Size.XLarge
            , docker = None Docker.Type
            , depends_on =
                DebianVersions.appDependsOn DebianVersions.DepsSpec::{=}
            }
        ]
      }
