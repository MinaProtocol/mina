let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Network = ../../Constants/Network.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

let network = Network.Type.Devnet

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{
        , network = network
        , build_flag = BuildFlags.Type.Instrumented
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/connect/connect-to-network" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ConnectToDevnet" "dhall"
          , S.exactly "buildkite/src/Command/ConnectToNetwork" "dhall"
          ]
        , path = "Test"
        , name = "ConnectToDevnet"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        , excludeIf =
          [ Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Mesa
              , reason = "Mesa does not have devnet network yet"
              }
          , Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Develop
              , reason =
                  "Develop branch is incompatible with current devnet network"
              }
          ]
        }
      , steps =
        [ ConnectToNetwork.step
            ConnectToNetwork.Spec::{
            , dependsOn = dependsOn
            , mina_suffix = "${Network.lowerName network}"
            , testnet = "${Network.lowerName network}"
            , peer_list_url = Network.peerListUrl network
            }
        ]
      }
