let Prelude = ../External/Prelude.dhall

let Channel : Type = < Unstable | Nightly | Itn | Devnet | Alpha | Beta | Stable >

let capitalName = \(channel : Channel) ->
  merge {
    Unstable = "Unstable"
    , Nightly = "Nightly"
    , Itn = "Itn"
    , Devnet = "Devnet"
    , Alpha = "Alpha"
    , Beta = "Beta"
    , Stable = "Stable"
  } channel

let lowerName = \(channel : Channel) ->
  merge {
   Unstable = "unstable"
    , Nightly = "nightly"
    , Itn = "itn"
    , Devnet = "devnet"
    , Alpha = "alpha"
    , Beta = "beta"
    , Stable = "stable"
  } channel

in
{
  Type = Channel
  , capitalName = capitalName
  , lowerName = lowerName
}
