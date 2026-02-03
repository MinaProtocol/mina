let S = ../Lib/SelectFiles.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let Command = ../Command/Base.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let Size = ../Command/Size.dhall

let Network = ../Constants/Network.dhall

let MainlineBranch = ../Pipeline/MainlineBranch.dhall

let Expr = ../Pipeline/Expr.dhall

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

let makeTest =
          \(name : Text)
      ->  \(scope : List PipelineScope.Type)
      ->  \(deps : List Command.TaggedKey.Type)
      ->  \(network : Network.Type)
      ->  \(expectedChainId : Text)
      ->  Pipeline.build
            Pipeline.Config::{
            , spec = JobSpec::{
              , dirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.exactly "buildkite/scripts/test-chain-id" "sh"
                , S.exactly "buildkite/src/Command/ChainIdTest" "dhall"
                , S.exactly "buildkite/src/Jobs/Test/ChainIdTestMainnet" "dhall"
                , S.exactly "buildkite/src/Jobs/Test/ChainIdTestDevnet" "dhall"
                ]
              , path = "Test"
              , name = name
              , tags =
                [ PipelineTag.Type.Fast
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              , scope = scope
              , excludeIf =
                [ Expr.Type.DescendantOf
                    { ancestor = MainlineBranch.Type.Mesa
                    , reason = "Mesa does not support this test yet"
                    }
                ]
              }
            , steps = [ buildTestStep network expectedChainId deps ]
            }

in  { makeTest = makeTest }
