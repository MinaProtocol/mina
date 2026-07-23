let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

let dependsOn =
        Dockers.dependsOn
          Dockers.DepsSpec::{ artifact = Artifacts.Type.DaemonAppsOnly }
      # Dockers.dependsOn
          Dockers.DepsSpec::{ artifact = Artifacts.Type.Archive }

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
              (S.contains "buildkite/scripts/run-test-executive-docker")
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
          List/map
            Text
            TestExecutive.Type
            (     \(testName : Text)
              ->  TestExecutive.execute
                    TestExecutive.Engine.Docker
                    testName
                    dependsOn
            )
            TestExecutive.tests
      }
