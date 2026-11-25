let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let RosettaBlockRaceTest = ../../Command/RosettaBlockRaceTest.dhall

let dependsOn = DebianVersions.appDependsOn DebianVersions.DepsSpec::{=}

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/rosetta/test-block-race-with-data" "sh"
          , S.exactly "scripts/rosetta/test-block-race" "sh"
          , S.exactly "buildkite/scripts/tests/rosetta/block-race-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/RosettaBlockRaceTest" "dhall"
          , S.exactly "buildkite/src/Command/RosettaBlockRaceTest" "dhall"
          ]
        , path = "Test"
        , name = "RosettaBlockRaceTest"
        , scope =
          [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ RosettaBlockRaceTest.step dependsOn ]
      }
