let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let ChainIdTest = ../../Command/ChainIdTest.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let scopes = [ PipelineScope.Type.MainlineNightly ]

let deps =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , network = Network.Type.Mainnet
        , profile = Profile.Type.Mainnet
        }

let expectedChainId =
      "a7351abc7ddf2ea92d1b38cc8e636c271c1dfd2c081c637f62ebc2af34eb7cc1"


let mainnetDeps =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , network = Network.Type.Mainnet
        , profile = Profile.Type.Mainnet
        }

in ChainIdTest.makeTest scopes deps Network.Type.Mainnet expectedChainId
