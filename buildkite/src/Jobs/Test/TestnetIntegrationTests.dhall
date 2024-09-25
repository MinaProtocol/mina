let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let Profiles = ../../Constants/Profiles.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let dependsOn =
        Dockers.dependsOn
          Dockers.Type.Bullseye
          (Some Network.Type.Berkeley)
          Profiles.Type.Standard
          Artifacts.Type.Daemon
      # Dockers.dependsOn
          Dockers.Type.Bullseye
          (None Network.Type)
          Profiles.Type.Standard
          Artifacts.Type.Archive

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart (S.contains "dockerfiles")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Command/TestExecutive")
          , S.strictlyStart
              (S.contains "automation/terraform/modules/o1-integration")
          , S.strictlyStart
              (S.contains "automation/terraform/modules/kubernetes/testnet")
          , S.strictlyStart
              ( S.contains
                  "automation/buildkite/script/run-test-executive-cloud"
              )
          , S.strictlyStart
              ( S.contains
                  "automation/buildkite/script/run-test-executive-local"
              )
          ]
        , path = "Test"
        , name = "TestnetIntegrationTests"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , mode = PipelineMode.Type.Stable
        }
      , steps =
        [ TestExecutive.executeLocal "peers-reliability" dependsOn
        , TestExecutive.executeLocal "chain-reliability" dependsOn
        , TestExecutive.executeLocal "payment" dependsOn
        , TestExecutive.executeLocal "gossip-consis" dependsOn
        , TestExecutive.executeLocal "block-prod-prio" dependsOn
        , TestExecutive.executeLocal "medium-bootstrap" dependsOn
        , TestExecutive.executeLocal "block-reward" dependsOn
        , TestExecutive.executeLocal "zkapps" dependsOn
        , TestExecutive.executeLocal "zkapps-timing" dependsOn
        , TestExecutive.executeLocal "zkapps-nonce" dependsOn
        , TestExecutive.executeLocal "verification-key" dependsOn
        , TestExecutive.executeLocal "slot-end" dependsOn
        , TestExecutive.executeLocal "epoch-ledger" dependsOn
        ]
      }
