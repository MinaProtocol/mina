let Prelude = ../External/Prelude.dhal


let Channel : Type = < Unstable | Nightly | Itn | Umt | Devnet | Alpha | Beta | Experimental | Stable >



let capitalName = \(channel : Channel) ->
  merge {
    Unstable = "Unstable"
    , Nightly = "Nightly"
    , Itn = "Itn"
    , Umt = "Umt"
    , Devnet = "Devnet"
    , Alpha = "Alpha"
    , Beta = "Beta"
    , Stable = "Stable"
    , Experimental = "Experimental"
  } channel

let lowerName = \(channel : Channel) ->
  merge {
   Unstable = "unstable"
    , Nightly = "nightly"
    , Itn = "itn"
    , Umt = "umt"
    , Devnet = "devnet"
    , Alpha = "alpha"
    , Beta = "beta"
    , Stable = "stable"
    , Experimental = "experimental"
  } channel

in
{
  Type = Channel
  , capitalName = capitalName
  , lowerName = lowerName
}
