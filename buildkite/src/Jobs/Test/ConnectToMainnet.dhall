let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Network = ../../Constants/Network.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Profile = ../../Constants/Profiles.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

let network = Network.Type.Mainnet

let dependsOn =
      Dockers.dependsOn
        Dockers.DepsSpec::{ network = network, profile = Profile.Type.Mainnet }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/connect/connect-to-network" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ConnectToMainnet" "dhall"
          , S.exactly "buildkite/src/Command/ConnectToNetwork" "dhall"
          ]
        , path = "Test"
        , name = "ConnectToMainnet"
        , scope =
          [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Rosetta
          ]
        , excludeIf =
          [ Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Mesa
              , reason = "Mesa does not have mainnet network yet"
              }
          , Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Develop
              , reason =
                  "Develop branch is incompatible with current mainnet network"
              }
          ]
        }
      , steps =
        [ ConnectToNetwork.step
            dependsOn
            "${Network.lowerName network}"
            "${Network.lowerName network}"
            "40s"
            "2m"
            (B/SoftFail.Boolean False)
        ]
      }
