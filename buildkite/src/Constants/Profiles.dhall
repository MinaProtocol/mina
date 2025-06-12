let Network = ./Network.dhall

let Profile
    : Type
    = < Devnet | Mainnet | Lightnet | Hardfork | Dev >

let capitalName =
          \(profile : Profile)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , Lightnet = "Lightnet"
            , Hardfork = "Hardfork"
            , Dev = "Dev"
            }
            profile

let lowerName =
          \(profile : Profile)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            , Dev = "dev"
            }
            profile

let duneProfile =
          \(profile : Profile)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            , Dev = "dev"
            }
            profile

let fromNetwork =
          \(network : Network.Type)
      ->  merge
            { Devnet = Profile.Devnet
            , Mainnet = Profile.Mainnet
            , Berkeley = Profile.Devnet
            }
            network

let toSuffixUppercase =
          \(profile : Profile)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , Lightnet = "Lightnet"
            , Hardfork = "Hardfork"
            , Dev = "Dev"
            }
            profile

let toSuffixLowercase =
          \(profile : Profile)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            , Dev = "dev"
            }
            profile

let toLabelSegment =
          \(profile : Profile)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "-mainnet"
            , Lightnet = "-lightnet"
            , Hardfork = "-hardfork"
            , Dev = "-dev"
            }
            profile

in  { Type = Profile
    , capitalName = capitalName
    , lowerName = lowerName
    , duneProfile = duneProfile
    , toSuffixUppercase = toSuffixUppercase
    , fromNetwork = fromNetwork
    , toSuffixLowercase = toSuffixLowercase
    , toLabelSegment = toLabelSegment
    }
