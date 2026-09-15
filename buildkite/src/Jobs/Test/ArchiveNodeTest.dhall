let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let ArchiveNodeTest = ../../Command/ArchiveNodeTest.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , buildFlags = BuildFlags.Type.Instrumented
        , artifact = Artifacts.Type.FunctionalTestSuite
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/patch-archive-test" "sh"
          , S.exactly "scripts/tests/archive-node-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ArchiveNodeTest" "dhall"
          , S.exactly "buildkite/src/Command/ArchiveNodeTest" "dhall"
          , S.exactly "buildkite/src/Command/Bench/Base" "dhall"
          , S.exactly "buildkite/scripts/bench/install" "sh"
          , S.exactly "buildkite/scripts/bench/run" "sh"
          , S.contains "scripts/benchmark"
          , S.exactly "buildkite/src/Jobs/Bench/ArchiveStable" "dhall"
          , S.exactly "buildkite/src/Jobs/Bench/ArchiveUnstable" "dhall"
          ]
        , path = "Test"
        , name = "ArchiveNodeTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          ]
        }
      , steps = [ ArchiveNodeTest.step dependsOn ]
      }
