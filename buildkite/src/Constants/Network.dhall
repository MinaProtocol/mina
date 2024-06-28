let Prelude = ../External/Prelude.dhall
let Profiles = ./Profiles.dhall

let Network: Type  = < Devnet | Mainnet >

let capitalName = \(network : Network) ->
  merge {
    Devnet = "Devnet"
    , Mainnet = "Mainnet"
  } network

let lowerName = \(network : Network) ->
  merge {
    Devnet = "devnet"
    , Mainnet = "mainnet"
  } network

in

{
  Type = Network
  , capitalName = capitalName
  , lowerName = lowerName
}