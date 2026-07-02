let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let Dockers = ../../Constants/Docker/Versions.dhall

let Docker = ../../Constants/Docker/Package.dhall

let Network = ../../Constants/Network.dhall

let dependsOn =
        Dockers.dependsOn
          Dockers.DepsSpec::{ artifact = Docker.Type.DaemonGeneric }
      # Dockers.dependsOn
          Dockers.DepsSpec::{
          , artifact = Docker.Type.Archive { network = Network.Type.Devnet }
          }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart (S.contains "dockerfiles")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest")
          , S.strictlyStart (S.contains "buildkite/src/Command/TestExecutive")
          ]
        , path = "Test"
        , name = "TestnetIntegrationTestsLong"
        , scope = PipelineScope.AllButPullRequest
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ TestExecutive.executeLocal "post-hard-fork" dependsOn ]
      }
