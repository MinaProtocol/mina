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
      | Mesa
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
            , Mesa = "Mesa"
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
            , Mesa = "mesa"
            }
            channel

in  { Type = Channel, capitalName = capitalName, lowerName = lowerName }
