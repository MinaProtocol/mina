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
          (Some Network.Type.Devnet)
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
          , S.strictlyStart (S.contains "buildkite/src/Command/TestExecutive")
          , S.strictlyStart
              (S.contains "automation/terraform/modules/o1-integration")
          , S.strictlyStart
              (S.contains "automation/terraform/modules/kubernetes/testnet")
          ]
        , path = "Test"
        , name = "TestnetIntegrationTestsLong"
        , mode = PipelineMode.Type.Stable
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ TestExecutive.executeLocal "hard-fork" dependsOn ]
      }
