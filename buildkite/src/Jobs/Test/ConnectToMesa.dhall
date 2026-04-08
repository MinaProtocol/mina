let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Network = ../../Constants/Network.dhall

let Dockers = ../../Constants/DockerVersions.dhall

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
        }
      , steps =
        [ ConnectToNetwork.step
            ConnectToNetwork.Spec::{
            , dependsOn = dependsOn
            , mina_suffix = "${Network.lowerName network}"
            , testnet = "testnet"
            , sync_timeout = "2min"
            , peer_list_url = Some
                "https://storage.googleapis.com/o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt"
            }
        ]
      }
