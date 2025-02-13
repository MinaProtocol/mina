let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PatchArchiveTest = ../../Command/PatchArchiveTest.dhall

let Profiles = ../../Constants/Profiles.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let dependsOn =
      DebianVersions.dependsOnStep
        (None Text)
        DebianVersions.DebVersion.Bullseye
        Profiles.Type.Standard
        BuildFlags.Type.Instrumented
        "build"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/tests/archive_patch_test" "sh"
          , S.exactly "buildkite/scripts/tests/archive_patch_test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/PatchArchiveTest" "dhall"
          , S.exactly "buildkite/src/Command/PatchArchiveTest" "dhall"
          ]
        , path = "Test"
        , name = "PatchArchiveTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ PatchArchiveTest.step dependsOn ]
      }
