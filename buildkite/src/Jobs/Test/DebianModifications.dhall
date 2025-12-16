let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Command = ../../Command/Base.dhall

let DebianModifications = ../../Command/DebianModifications.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "scripts/debian/session")
          , S.exactly "scripts/debian/session/tests/run-deb-session-tests" "sh"
          , S.exactly "buildkite/src/Jobs/Test/DebianModifications" "dhall"
          , S.exactly "buildkite/src/Command/DebianModifications" "dhall"
          ]
        , path = "Test"
        , name = "DebianModifications"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Debian
          ]
        }
      , steps = [ DebianModifications.step ([] : List Command.TaggedKey.Type) ]
      }
