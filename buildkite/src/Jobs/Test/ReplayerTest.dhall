let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let ReplayerTest = ../../Command/ReplayerTest.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DebVersion.Bullseye
        Profiles.Type.Standard

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/tests/archive_replayer_test" "sh"
          , S.exactly "buildkite/scripts/tests/archive_replayer_test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ReplayerTest" "dhall"
          , S.exactly "buildkite/src/Command/ReplayerTest" "dhall"
          ]
        , path = "Test"
        , name = "ReplayerTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ ReplayerTest.step dependsOn ]
      }
