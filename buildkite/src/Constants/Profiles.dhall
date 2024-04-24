let Prelude = ../External/Prelude.dhall

let Profile : Type = < Devnet | Mainnet >

let capitalName = \(profile : Profile) ->
  merge {
    Devnet = "Devnet"
    , Mainnet = "Mainnet"
  } profile

let lowerName = \(profile : Profile) ->
  merge {
    Devnet = "devnet"
    , Mainnet = "mainnet"
  } profile

let duneProfile = \(profile : Profile) ->
  merge {
    Devnet = "devnet"
    , Mainnet = "mainnet"
  } profile

let toLabelSegment = \(profile : Profile) ->
  merge {
    , Devnet = "-devnet"
    , Mainnet = "-mainnet"
  } profile



in

{
  Type = Profile
  , capitalName = capitalName
  , lowerName = lowerName
  , duneProfile = duneProfile
  , toLabelSegment = toLabelSegment
}