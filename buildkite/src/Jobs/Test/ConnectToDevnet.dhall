let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToTestnet = ../../Command/ConnectToTestnet.dhall

let Profiles = ../../Constants/Profiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DebVersion.Bullseye
        Network.Type.Devnet
        Profiles.Type.Standard

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/connect-to-testnet" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ConnectToDevnet" "dhall"
          , S.exactly "buildkite/src/Command/ConnectToTestnet" "dhall"
          ]
        , path = "Test"
        , name = "ConnectToDevnet"
        , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
        }
      , steps =
        [ ConnectToTestnet.step
            dependsOn
            "${Network.lowerName Network.Type.Devnet}"
            "40s"
            "2m"
            (B/SoftFail.Boolean True)
        ]
      }
