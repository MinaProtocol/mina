let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let ConnectToNetwork = ../../Command/ConnectToNetwork.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Network = ../../Constants/Network.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let network = Network.Type.Mainnet

let dependsOn =
      Dockers.dependsOn
        Dockers.Type.Bullseye
        network
        Profiles.Type.Standard
        Artifacts.Type.Daemon

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
        , mode = PipelineMode.Type.Stable
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
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
