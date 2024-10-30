let Channel
    : Type
    = < Unstable
      | NightlyDevelop
      | NightlyCompatible
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
            , NightlyDevelop = "NightlyDevelop"
            , NightlyCompatible = "NightlyCompatible"
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
            , NightlyDevelop = "nightly-develop"
            , NightlyCompatible = "nightly-compatible"
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
