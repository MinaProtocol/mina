let Network
    : Type
    = < Devnet | Mainnet | Berkeley >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet", Mainnet = "Mainnet", Berkeley = "Berkeley" }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet", Mainnet = "mainnet", Berkeley = "berkeley" }
            network

in  { Type = Network, capitalName = capitalName, lowerName = lowerName }
