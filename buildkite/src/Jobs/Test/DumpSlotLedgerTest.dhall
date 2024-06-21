let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let DumpSlotLedgerTest = ../../Command/DumpSlotLedgerTest.dhall
let Profiles = ../../Constants/Profiles.dhall
let Dockers = ../../Constants/DockerVersions.dhall

let dependsOn = Dockers.dependsOn Dockers.Type.Bullseye Profiles.Type.Standard "archive"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/dump-slot-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/DumpSlotLedgerTest" "dhall"
          , S.exactly "buildkite/src/Command/DumpSlotLedgerTest" "dhall"
          , S.exactly "scripts/dump-slot-test" "sh"
          ]
        , path = "Test"
        , name = "DumpSlotLedgerTest"
        , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
        }
      , steps = [ DumpSlotLedgerTest.step dependsOn ]
      }
