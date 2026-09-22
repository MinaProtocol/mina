let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let Command = ../../Command/Base.dhall

let dependsOn
    : List Command.TaggedKey.Type
    = [ { name = "IntegrationTestDockerImages"
        , key = "daemon_apps_only-docker-image"
        }
      , { name = "IntegrationTestDockerImages", key = "archive-docker-image" }
      ]

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
