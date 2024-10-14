let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let ReplayerTest = ../../Command/ReplayerTest.dhall

let Profiles = ../../Constants/Profiles.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.Type.Bullseye
        (None Network.Type)
        Profiles.Type.Standard
        Artifacts.Type.Archive

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/replayer-test" "sh"
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
