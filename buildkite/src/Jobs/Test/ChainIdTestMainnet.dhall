let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let ChainIdTest = ../../Command/ChainIdTest.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let scopes = [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]

let network = Network.Type.Mainnet

let deps = DebianVersions.appDependsOn DebianVersions.DepsSpec::{=}

let expectedChainId =
      "0718f61ab88f9d0fa643ff4dc3a3d5998dd6d51a6008b2b0339b0dbb26133886"

in  ChainIdTest.makeTest
      "ChainIdTestMainnet"
      scopes
      deps
      network
      expectedChainId
