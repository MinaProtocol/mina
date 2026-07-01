let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutiveLocalApps = ../../Command/TestExecutiveLocalApps.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let dependsOn = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart
              ( S.contains
                  "buildkite/src/Jobs/Test/TestnetIntegrationTestsLocalApps"
              )
          , S.strictlyStart
              (S.contains "buildkite/src/Command/TestExecutiveLocalApps")
          , S.strictlyStart
              (S.contains "buildkite/scripts/run-test-executive-local-apps")
          ]
        , path = "Test"
        , name = "TestnetIntegrationTestsLocalApps"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , scope = PipelineScope.AllButPullRequest
        }
      , steps =
        [ TestExecutiveLocalApps.executeLocalApps "block-prod-prio" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "block-reward" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "chain-reliability" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "epoch-ledger" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "genesis-export" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "gossip-consis" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "medium-bootstrap" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "payments" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "peers-reliability" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "slot-end" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "verification-key" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "zkapps" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "zkapps-timing" dependsOn
        , TestExecutiveLocalApps.executeLocalApps "zkapps-nonce" dependsOn
        ]
      }
