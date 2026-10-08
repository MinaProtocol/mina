let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let ChainIdTest = ../../Command/ChainIdTest.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let scopes = [ PipelineScope.Type.PullRequest ]

let network = Network.Type.Devnet

let deps = DebianVersions.appDependsOn DebianVersions.DepsSpec::{=}

let expectedChainId =
      "ebfce0d570bc22eb041e1a7b0a46bbc3ed5d0a1030ef2ab5e36eef908b93eba8"

in  ChainIdTest.makeTest "ChainIdTestDevnet" scopes deps network expectedChainId
