let Prelude = ../External/Prelude.dhall

let Profile : Type = < Standard | Lightnet | Hardfork >

let capitalName = \(profile : Profile) ->
  merge {
    Standard = "Standard"
    , Lightnet = "Lightnet"
    , Hardfork = "Hardfork"
  } profile

let lowerName = \(profile : Profile) ->
  merge {
    Standard = "standard"
    , Lightnet = "lightnet"
    , Hardfork = "hardfork"
  } profile

let duneProfile = \(profile : Profile) ->
  merge {
    Standard = "devnet"
    , Lightnet = "lightnet"
    , Hardfork = "hardfork"
  } profile

let toSuffixUppercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "Lightnet"
    , Hardfork = "Hardfork"
  } profile

let toSuffixLowercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "lightnet"
    , Hardfork = "hardfork"
  } profile

let toLabelSegment = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "-lightnet"
    , Hardfork = "-hardfork"
  } profile



in

{
  Type = Profile
  , capitalName = capitalName
  , lowerName = lowerName
  , duneProfile = duneProfile
  , toSuffixUppercase = toSuffixUppercase
  , toSuffixLowercase = toSuffixLowercase
  , toLabelSegment = toLabelSegment
}
