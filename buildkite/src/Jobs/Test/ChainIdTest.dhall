let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Size = ../../Command/Size.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let buildTestStep =
          \(network : Network.Type)
      ->  \(expectedChainId : Text)
      ->  \(dependsOn : List Command.TaggedKey.Type)
      ->  let networkName = Network.lowerName network

          in  Command.build
                Command.Config::{
                , commands =
                    RunInToolchain.runInToolchain
                      ([] : List Text)
                      "buildkite/scripts/test-chain-id.sh ${networkName} ${expectedChainId}"
                , label = "Test chain-id for ${networkName}"
                , key = "test-chain-id-${networkName}"
                , target = Size.Small
                , depends_on = dependsOn
                }

let devnetDeps =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , network = Network.Type.Devnet
        , profile = Profile.Type.Devnet
        }

let mainnetDeps =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , network = Network.Type.Mainnet
        , profile = Profile.Type.Mainnet
        }

 let devnetExpectedChainId =
      "b00df7e2823d671b0cf1aeadce7dcfe907b6fc65062c531a10f7d4db446b2b9f"

 let mainnetExpectedChainId =
      "cfb2d9ba2e5c9a59b559853c2bd8dff6b5eb4809c39fb68842a8d4853d88b9c6"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/test-chain-id" "sh"
          , S.exactly "buildkite/src/Jobs/Test/ChainIdTest" "dhall"
          ]
        , path = "Test"
        , name = "ChainIdTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ buildTestStep Network.Type.Devnet devnetExpectedChainId devnetDeps
        , buildTestStep Network.Type.Mainnet mainnetExpectedChainId mainnetDeps
        ]
      }
