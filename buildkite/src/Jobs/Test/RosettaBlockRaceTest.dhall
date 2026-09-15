let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let RosettaBlockRaceTest = ../../Command/RosettaBlockRaceTest.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , artifact = Artifacts.Type.FunctionalTestSuite
        , buildFlags = BuildFlags.Type.Instrumented
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "scripts/rosetta/test-block-race-with-data" "sh"
          , S.exactly "scripts/rosetta/test-block-race" "sh"
          , S.exactly "buildkite/scripts/tests/rosetta-block-race-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/RosettaBlockRaceTest" "dhall"
          , S.exactly "buildkite/src/Command/RosettaBlockRaceTest" "dhall"
          ]
        , path = "Test"
        , name = "RosettaBlockRaceTest"
        , excludeIf =
          [ Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Mesa
              , reason = "Mesa does not support devnet network yet"
              }
          , Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Develop
              , reason =
                  "Develop branch is incompatible with current devnet network"
              }
          ]
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ RosettaBlockRaceTest.step dependsOn ]
      }
