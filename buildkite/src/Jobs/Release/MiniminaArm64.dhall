let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Arch = ../../Constants/Arch.dhall

let MiniminaCommand = ../../Command/Minimina.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "src/app/minimina"
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Release/MiniminaArm64")
          , S.strictlyStart (S.contains "buildkite/src/Command/Minimina")
          , S.contains "scripts/debian/builder-helpers.sh"
          ]
        , path = "Release"
        , name = "MiniminaArm64"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Release
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Arm64
          ]
        , scope = PipelineScope.AllButPullRequest
        }
      , steps =
        [ MiniminaCommand.buildStep
            Arch.Type.Arm64
            (Some (B/SoftFail.Boolean True))
        ]
      }
