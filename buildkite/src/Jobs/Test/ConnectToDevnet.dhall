let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Network = ../../Constants/Network.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let network = Network.Type.Devnet

let dependsOn = Dockers.dependsOn Dockers.DepsSpec::{ network = network }

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
        }
      , steps =
        [ ConnectToNetwork.step
            dependsOn
            "${Network.debianSuffix network}"
            "${Network.debianSuffix network}"
            "40s"
            "2m"
            (B/SoftFail.Boolean False)
        ]
      }
