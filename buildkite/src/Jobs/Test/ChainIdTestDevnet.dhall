let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let ChainIdTest = ../../Command/ChainIdTest.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let scopes = [ PipelineScope.Type.PullRequest ]

let network = Network.Type.Devnet

let deps =
      Dockers.dependsOn
        Dockers.DepsSpec::{ network = network, profile = Profile.Type.Devnet }

let expectedChainId =
      "8c6312664c60ecc4c0c695e69f6301692c0b20f354b55e08e69a289f3d373e50"

in  ChainIdTest.makeTest "ChainIdTestDevnet" scopes deps network expectedChainId
