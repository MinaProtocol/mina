let Network = ./Network.dhall

let Profile
    : Type
    = < Devnet | Mainnet | Lightnet | Dev >

let capitalName =
      \(profile : Profile) ->
        merge
          { Devnet = "Devnet"
          , Mainnet = "Mainnet"
          , Lightnet = "Lightnet"
          , Dev = "Dev"
          }
          profile

let lowerName =
      \(profile : Profile) ->
        merge
          { Devnet = "devnet"
          , Mainnet = "mainnet"
          , Lightnet = "lightnet"
          , Dev = "dev"
          }
          profile

let duneProfile =
      \(profile : Profile) ->
        merge
          { Devnet = "devnet"
          , Mainnet = "mainnet"
          , Lightnet = "lightnet"
          , Dev = "dev"
          }
          profile

let fromNetwork =
      \(network : Network.Type) ->
        merge
          { Devnet = Profile.Devnet
          , Mainnet = Profile.Mainnet
          , Berkeley = Profile.Devnet
          , DevnetLegacy = Profile.Devnet
          , MainnetLegacy = Profile.Mainnet
          }
          network

let toSuffixUppercase =
      \(profile : Profile) ->
        merge
          { Devnet = "Devnet"
          , Mainnet = "Mainnet"
          , Lightnet = "Lightnet"
          , Dev = "Dev"
          }
          profile

let toSuffixLowercase =
      \(profile : Profile) ->
        merge
          { Devnet = "devnet"
          , Mainnet = "mainnet"
          , Lightnet = "lightnet"
          , Dev = "dev"
          }
          profile

let toLabelSegment =
      \(profile : Profile) ->
        merge
          { Devnet = "devnet"
          , Mainnet = "-mainnet"
          , Lightnet = "-lightnet"
          , Dev = "-dev"
          }
          profile

in  { Type = Profile
    , capitalName
    , lowerName
    , duneProfile
    , toSuffixUppercase
    , fromNetwork
    , toSuffixLowercase
    , toLabelSegment
    }
