let Network = ./Network.dhall

let Profile
    : Type
    = < PublicNetwork | Lightnet | Dev >

let capitalName =
          \(profile : Profile)
      ->  merge
            { PublicNetwork = "PublicNetwork"
            , Lightnet = "Lightnet"
            , Dev = "Dev"
            }
            profile

let lowerName =
          \(profile : Profile)
      ->  merge
            { PublicNetwork = "publicnetwork"
            , Lightnet = "lightnet"
            , Dev = "dev"
            }
            profile

let duneProfile =
          \(profile : Profile)
      ->  merge
            { PublicNetwork = "public_network"
            , Lightnet = "lightnet"
            , Dev = "dev"
            }
            profile

let toSuffixUppercase =
          \(profile : Profile)
      ->  merge
            { PublicNetwork = ""
            , Lightnet = "Lightnet"
            , Dev = "Dev"
            }
            profile

let toSuffixLowercase =
          \(profile : Profile)
      ->  merge
            { PublicNetwork = ""
            , Lightnet = "lightnet"
            , Dev = "dev"
            }
            profile

let toLabelSegment =
          \(profile : Profile)
      ->  merge
            { PublicNetwork = ""
            , Lightnet = "lightnet"
            , Dev = "dev"
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
