let Profile
    : Type
    = < Standard | Mainnet | Lightnet | Hardfork | Dev >

let capitalName =
          \(profile : Profile)
      ->  merge
            { Standard = "Standard"
            , Mainnet = "Mainnet"
            , Lightnet = "Lightnet"
            , Hardfork = "Hardfork"
            , Dev = "Dev"
            }
            profile

let lowerName =
          \(profile : Profile)
      ->  merge
            { Standard = "standard"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            , Dev = "dev"
            }
            profile

let duneProfile =
          \(profile : Profile)
      ->  merge
            { Standard = "devnet"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            , Dev = "dev"
            }
            profile

let toSuffixUppercase =
          \(profile : Profile)
      ->  merge
            { Standard = ""
            , Mainnet = "Mainnet"
            , Lightnet = "Lightnet"
            , Hardfork = "Hardfork"
            , Dev = "Dev"
            }
            profile

let toSuffixLowercase =
          \(profile : Profile)
      ->  merge
            { Standard = ""
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            , Dev = "dev"
            }
            profile

let toLabelSegment =
          \(profile : Profile)
      ->  merge
            { Standard = ""
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
    , toSuffixLowercase = toSuffixLowercase
    , toLabelSegment = toLabelSegment
    }
