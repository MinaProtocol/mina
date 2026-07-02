let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let ReplayerMesaHfTest = ../../Command/ReplayerMesaHfTest.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{ build_flag = BuildFlags.Type.Instrumented }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/replayer-mesa-hf-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ReplayerMesaHfTest" "dhall"
          , S.exactly "buildkite/src/Command/ReplayerMesaHfTest" "dhall"
          ]
        , path = "Test"
        , name = "ReplayerMesaHfTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          , PipelineTag.Type.Hardfork
          ]
        }
      , steps = [ ReplayerMesaHfTest.step dependsOn ]
      }
