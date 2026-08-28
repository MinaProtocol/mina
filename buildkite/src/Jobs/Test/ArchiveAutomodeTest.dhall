let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let ArchiveAutomodeTest = ../../Command/ArchiveAutomodeTest.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

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
          , S.exactly "buildkite/scripts/archive-automode-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ArchiveAutomodeTest" "dhall"
          , S.exactly "buildkite/src/Command/ArchiveAutomodeTest" "dhall"
          ]
        , path = "Test"
        , name = "ArchiveAutomodeTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          , PipelineTag.Type.Hardfork
          ]
        }
      , steps = [ ArchiveAutomodeTest.step dependsOn ]
      }
