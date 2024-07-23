let Profile
    : Type
    = < Standard | Mainnet | Lightnet | Hardfork >

let capitalName =
          \(profile : Profile)
      ->  merge
            { Standard = "Standard"
            , Mainnet = "Mainnet"
            , Lightnet = "Lightnet"
            , Hardfork = "Hardfork"
            }
            profile

let lowerName =
          \(profile : Profile)
      ->  merge
            { Standard = "standard"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            }
            profile

let duneProfile =
          \(profile : Profile)
      ->  merge
            { Standard = "devnet"
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            }
            profile

let toSuffixUppercase =
          \(profile : Profile)
      ->  merge
            { Standard = ""
            , Mainnet = "Mainnet"
            , Lightnet = "Lightnet"
            , Hardfork = "Hardfork"
            }
            profile

let toSuffixLowercase =
          \(profile : Profile)
      ->  merge
            { Standard = ""
            , Mainnet = "mainnet"
            , Lightnet = "lightnet"
            , Hardfork = "hardfork"
            }
            profile

let toLabelSegment =
          \(profile : Profile)
      ->  merge
            { Standard = ""
            , Mainnet = "-mainnet"
            , Lightnet = "-lightnet"
            , Hardfork = "-hardfork"
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
