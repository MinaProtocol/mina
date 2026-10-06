let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let IntegrationImages = ../../Constants/IntegrationImages.dhall

let dependsOn = IntegrationImages.dependsOn

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart (S.contains "dockerfiles")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest")
          , S.strictlyStart (S.contains "buildkite/src/Command/TestExecutive")
          , S.exactly "buildkite/src/Constants/IntegrationImages" "dhall"
          , S.strictlyStart
              (S.contains "buildkite/scripts/run-test-executive-docker")
          , S.strictlyStart (S.contains "buildkite/scripts/apps")
          ]
        , path = "Test"
        , name = "TestnetIntegrationTests"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , scope = PipelineScope.AllButPullRequest
        }
      , steps =
        [ TestExecutive.executeDocker "block-prod-prio" dependsOn
        , TestExecutive.executeDocker "block-reward" dependsOn
        , TestExecutive.executeDocker "chain-reliability" dependsOn
        , TestExecutive.executeDocker "epoch-ledger" dependsOn
        , TestExecutive.executeDocker "genesis-export" dependsOn
        , TestExecutive.executeDocker "gossip-consis" dependsOn
        , TestExecutive.executeDocker "medium-bootstrap" dependsOn
        , TestExecutive.executeDocker "payments" dependsOn
        , TestExecutive.executeDocker "peers-reliability" dependsOn
        , TestExecutive.executeDocker "slot-end" dependsOn
        , TestExecutive.executeDocker "verification-key" dependsOn
        , TestExecutive.executeDocker "zkapps" dependsOn
        , TestExecutive.executeDocker "zkapps-timing" dependsOn
        , TestExecutive.executeDocker "zkapps-nonce" dependsOn
        ]
      }
