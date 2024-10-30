let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Command = ../../Command/FuzzyZkappTest.dhall

in  Pipeline.build
      ( Command.pipeline
          Command.Spec::{
          , job_path = "Test"
          , job_name = "FuzzyZkappTest"
          , tags = [ PipelineTag.Type.VeryLong, PipelineTag.Type.Test ]
          , mode = PipelineMode.Type.Stable
          , additional_dirty_when =
            [ S.exactly "buildkite/src/Jobs/Test/FuzzyZkappTest" "dhall" ]
          , timeout = 1200
          }
      )
