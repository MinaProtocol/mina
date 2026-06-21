let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Network = ../../Constants/Network.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

let network = Network.Type.Devnet

let dependsOn =
      DebianVersions.dependsOn DebianVersions.DepsSpec::{ network = network }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "scripts/debian")
          , S.strictlyStart (S.contains "scripts/rocksdb")
          , S.exactly
              "buildkite/scripts/connect/connect-to-network-migration"
              "sh"
          , S.exactly "buildkite/src/Jobs/Test/ConnectToDevnetMigration" "dhall"
          , S.exactly "buildkite/src/Command/ConnectToNetwork" "dhall"
          ]
        , path = "Test"
        , name = "ConnectToDevnetMigration"
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
            , script =
                "./buildkite/scripts/connect/connect-to-network-migration.sh"
            }
        ]
      }
