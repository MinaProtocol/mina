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
      "29936104443aaf264a7f0192ac64b1c7173198c1ed404c1bcff5e562e05eb7f6"

let mainnetExpectedChainId =
      "a7351abc7ddf2ea92d1b38cc8e636c271c1dfd2c081c637f62ebc2af34eb7cc1"

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
