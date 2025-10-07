let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | Base | Legacy >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , Base = "Base"
            , Legacy = "Legacy"
            }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , Base = "base"
            , Legacy = "legacy"
            }
            network

in  { Type = Network
    , capitalName = capitalName
    , lowerName = lowerName
    }
