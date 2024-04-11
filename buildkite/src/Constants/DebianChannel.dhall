let Prelude = ../External/Prelude.dhall

let Channel : Type = < Unstable | Nightly | Itn | Umt | Alpha | Beta | Stable >

let capitalName = \(channel : Channel) ->
  merge {
    Unstable = "Unstable"
    , Nightly = "Nightly"
    , Itn = "Itn"
    , Umt = "Umt"
    , Alpha = "Alpha"
    , Beta = "Beta"
    , Stable = "Stable"
  } channel

let lowerName = \(channel : Channel) ->
  merge {
   Unstable = "unstable"
    , Nightly = "nightly"
    , Itn = "itn"
    , Umt = "umt"
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
