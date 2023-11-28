let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let ReplayerTest = ../../Command/ReplayerTest.dhall
let Profiles = ../../Constants/Profiles.dhall
let Dockers = ../../Constants/DockerVersions.dhall

let dependsOn = Dockers.dependsOn Dockers.Type.Bullseye Profiles.Type.Standard "archive"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/replayer-test" "sh"
          ]
        , path = "Test"
        , name = "ReplayerTest"
        }
      , steps = [ ReplayerTest.step dependsOn ]
      }
