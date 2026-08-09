let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

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
          , S.strictlyStart (S.contains "buildkite/src/Command/TestExecutive")
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
          List/map
            Text
            TestExecutive.Type
            (     \(testName : Text)
              ->  TestExecutive.execute
                    TestExecutive.Engine.Native
                    testName
                    dependsOn
            )
            TestExecutive.tests
      }
