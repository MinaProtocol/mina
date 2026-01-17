let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart
              ( S.contains
                  "buildkite/scripts/tests/convert-debian-to-hf-test.sh"
              )
          , S.strictlyStart
              (S.contains "scripts/hardfork/convert-daemon-debian-to-hf.sh")
          , S.strictlyStart (S.contains "scripts/debian/session")
          ]
        , path = "Test"
        , name = "HardforkPackageConversion"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "buildkite/scripts/tests/convert-debian-to-hf-test.sh"
            , label = "Hardfork: Package Conversion"
            , key = "hf-package-conversion-test"
            , target = Size.Large
            , depends_on = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}
            }
        ]
      }
