let Prelude = ../External/Prelude.dhall

let BuildFlags : Type = < Standard | Instrumented >

let capitalName = \(buildFlags : BuildFlags) ->
  merge {
    Standard = "Standard"
    , Instrumented = "Instrumented"
  } buildFlags

let lowerName = \(buildFlags : BuildFlags) ->
  merge {
    Standard = "standard"
    , Instrumented = "instrumented"
  } buildFlags

let buildEnvs = \(buildFlags : BuildFlags) ->
  merge {
    Standard = ([] : List Text )
    , Instrumented = ["DUNE_INSTRUMENT_WITH=bisect_ppx"]
  } buildFlags

let toSuffixUppercase = \(buildFlags : BuildFlags) ->
  merge {
    Standard = ""
    , Instrumented = "Instrumented"
  } buildFlags

let toSuffixLowercase = \(buildFlags : BuildFlags) ->
  merge {
    Standard = ""
    , Instrumented = "instrumented"
  } buildFlags

let toLabelSegment = \(buildFlags : BuildFlags) ->
  merge {
    Standard = ""
    , Instrumented = "-instrumented"
  } buildFlags



in

{
  Type = BuildFlags
  , capitalName = capitalName
  , lowerName = lowerName
  , buildEnvs = buildEnvs
  , toSuffixUppercase = toSuffixUppercase
  , toSuffixLowercase = toSuffixLowercase
  , toLabelSegment = toLabelSegment
}