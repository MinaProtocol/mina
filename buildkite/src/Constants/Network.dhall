let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | Berkeley | DevnetLegacy | MainnetLegacy >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , Berkeley = "Berkeley"
            , DevnetLegacy = "DevnetLegacy"
            , MainnetLegacy = "MainnetLegacy"
            }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , Berkeley = "berkeley"
            , DevnetLegacy = "devnet_legacy"
            , MainnetLegacy = "mainnet_legacy"
            }
            network

in  { Type = Network
    , capitalName = capitalName
    , lowerName = lowerName
    }
