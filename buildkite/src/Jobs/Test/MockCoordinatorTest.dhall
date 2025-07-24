let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let MockCoordinatorTest = ../../Command/MockCoordinatorTest.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , artifact = Artifacts.Type.FunctionalTestSuite
        , buildFlags = BuildFlags.Type.Instrumented
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/tests/mock_coordinator" "sh"
          , S.exactly "buildkite/src/Jobs/Test/MockCoordinatorTest" "dhall"
          , S.exactly "buildkite/src/Command/MockCoordinatorTest" "dhall"
          ]
        , path = "Test"
        , name = "MockCoordinatorTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ MockCoordinatorTest.step dependsOn ]
      }
