let Prelude = ../External/Prelude.dhall

let Profile : Type = < Standard | Lightnet >

let capitalName = \(profile : Profile) ->
  merge {
    Standard = "Standard"
    , Lightnet = "Lightnet"
  } profile

let lowerName = \(profile : Profile) ->
  merge {
    Standard = "standard"
    , Lightnet = "lightnet"
  } profile

let duneProfile = \(profile : Profile) ->
  merge {
    Standard = "devnet"
    , Lightnet = "lightnet"
  } profile

let toSuffixUppercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "Lightnet"
  } profile

let toSuffixLowercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "lightnet"
  } profile

let toLabelSegment = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "-lightnet"
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
