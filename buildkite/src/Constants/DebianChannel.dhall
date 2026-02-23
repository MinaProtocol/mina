let Channel
    : Type
    = < Unstable
      | Develop
      | Compatible
      | Master
      | Itn
      | Umt
      | UmtMainnet
      | Devnet
      | Alpha
      | Beta
      | Experimental
      | Stable
      >

let capitalName =
          \(channel : Channel)
      ->  merge
            { Unstable = "Unstable"
            , Develop = "Develop"
            , Compatible = "Compatible"
            , Master = "Master"
            , Itn = "Itn"
            , Umt = "Umt"
            , UmtMainnet = "UmtMainnet"
            , Devnet = "Devnet"
            , Alpha = "Alpha"
            , Beta = "Beta"
            , Stable = "Stable"
            , Experimental = "Experimental"
            }
            channel

let lowerName =
          \(channel : Channel)
      ->  merge
            { Unstable = "unstable"
            , Develop = "develop"
            , Compatible = "compatible"
            , Master = "master"
            , Itn = "itn"
            , Umt = "umt"
            , UmtMainnet = "umt-mainnet"
            , Devnet = "devnet"
            , Alpha = "alpha"
            , Beta = "beta"
            , Stable = "stable"
            , Experimental = "experimental"
            }
            channel

in  { Type = Channel, capitalName = capitalName, lowerName = lowerName }
