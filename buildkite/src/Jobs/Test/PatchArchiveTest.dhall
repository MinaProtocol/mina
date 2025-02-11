let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PatchArchiveTest = ../../Command/PatchArchiveTest.dhall

let Profiles = ../../Constants/Profiles.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.Type.Bullseye
        Network.Type.Devnet
        Profiles.Type.Standard
        Artifacts.Type.FunctionalTestSuite

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/patch-archive-test" "sh"
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
