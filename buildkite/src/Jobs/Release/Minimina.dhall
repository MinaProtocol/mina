let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let MiniminaCommand = ../../Command/Minimina.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "src/app/minimina"
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/Minimina")
          , S.strictlyStart (S.contains "buildkite/src/Command/Minimina")
          , S.contains "scripts/debian/builder-helpers.sh"
          ]
        , path = "Release"
        , name = "Minimina"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Release
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ MiniminaCommand.buildStep (None B/SoftFail) ]
      }
