-- Converts a daemon .deb built by MinaArtifactNoble into its hardfork
-- variant, so it can only run in a stage that also runs the packaging jobs.
--
-- Hence the Packaging tag rather than Fast. Tagged Fast, the nightly's FastOnly
-- stage selected it while packaging (moved to its own tag in 2ee630be3e) did
-- not run there, so every night it sat waiting_failed on a dependency that was
-- never scheduled -- and took the tear-down step down with it.

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart
              ( S.contains
                  "scripts/hardfork/release/convert-daemon-debian-to-hf.sh"
              )
          , S.strictlyStart (S.contains "scripts/debian/session")
          ]
        , path = "Test"
        , name = "HardforkPackageConversion"
        , tags =
          [ PipelineTag.Type.Packaging
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInDefaultToolchain
                  DebianVersions.overrideEnvs
                  "buildkite/scripts/tests/convert-debian-to-hf-test.sh"
            , label = "Hardfork: Package Conversion"
            , key = "hf-package-conversion-test"
            , target = Size.Large
            , depends_on =
                DebianVersions.dependsOn
                  DebianVersions.DepsSpec::{ network = Network.Type.Devnet }
            }
        ]
      }
