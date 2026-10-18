let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let CacheManagerTest = ../../Command/CacheManagerTest.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/scripts/cache")
          , S.exactly "buildkite/src/Jobs/Test/CacheManagerTest" "dhall"
          , S.exactly "buildkite/src/Command/CacheManagerTest" "dhall"
          ]
        , path = "Test"
        , name = "CacheManagerTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ CacheManagerTest.bashStep, CacheManagerTest.toolStep ]
      }
