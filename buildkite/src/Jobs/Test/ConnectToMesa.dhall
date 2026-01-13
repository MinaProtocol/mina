let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Network = ../../Constants/Network.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

let network = Network.Type.Mesa

let dependsOn =
      Dockers.dependsOn Dockers.DepsSpec::{ network = Network.Type.Mesa }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/connect/connect-to-network" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ConnectToMesa" "dhall"
          , S.exactly "buildkite/src/Command/ConnectToNetwork" "dhall"
          , S.exactly "buildkite/src/Command/ConnectToNetwork" "dhall"
          ]
        , path = "Test"
        , name = "ConnectToMesa"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , includeIf =
          [ Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Mesa
              , reason = "Connect to Canary network on Mesa"
              }
          ]
        }
      , steps =
        [ ConnectToNetwork.step
            dependsOn
            "${Network.lowerName network}"
            "testnet"
            "40s"
            "2m"
            (B/SoftFail.Boolean False)
        ]
      }
