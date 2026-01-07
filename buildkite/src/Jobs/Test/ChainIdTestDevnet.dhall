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
      "29936104443aaf264a7f0192ac64b1c7173198c1ed404c1bcff5e562e05eb7f6"

in  ChainIdTest.makeTest scopes deps network expectedChainId
