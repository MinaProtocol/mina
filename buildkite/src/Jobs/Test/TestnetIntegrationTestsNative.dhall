let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutiveNative = ../../Command/TestExecutiveNative.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let dependsOn = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart
              ( S.contains
                  "buildkite/src/Jobs/Test/TestnetIntegrationTestsNative"
              )
          , S.strictlyStart
              (S.contains "buildkite/src/Command/TestExecutiveNative")
          , S.strictlyStart
              (S.contains "buildkite/scripts/run-test-executive-native")
          ]
        , path = "Test"
        , name = "TestnetIntegrationTestsNative"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , scope = PipelineScope.AllButPullRequest
        }
      , steps =
        [ TestExecutiveNative.executeNative "block-prod-prio" dependsOn
        , TestExecutiveNative.executeNative "block-reward" dependsOn
        , TestExecutiveNative.executeNative "chain-reliability" dependsOn
        , TestExecutiveNative.executeNative "epoch-ledger" dependsOn
        , TestExecutiveNative.executeNative "genesis-export" dependsOn
        , TestExecutiveNative.executeNative "gossip-consis" dependsOn
        , TestExecutiveNative.executeNative "medium-bootstrap" dependsOn
        , TestExecutiveNative.executeNative "payments" dependsOn
        , TestExecutiveNative.executeNative "peers-reliability" dependsOn
        , TestExecutiveNative.executeNative "slot-end" dependsOn
        , TestExecutiveNative.executeNative "verification-key" dependsOn
        , TestExecutiveNative.executeNative "zkapps" dependsOn
        , TestExecutiveNative.executeNative "zkapps-timing" dependsOn
        , TestExecutiveNative.executeNative "zkapps-nonce" dependsOn
        ]
      }
