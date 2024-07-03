let BuildFlags
    : Type
    = < None | Instrumented >

let capitalName =
          \(buildFlags : BuildFlags)
      ->  merge { None = "None", Instrumented = "Instrumented" } buildFlags

let lowerName =
          \(buildFlags : BuildFlags)
      ->  merge { None = "none", Instrumented = "instrumented" } buildFlags

let buildEnvs =
          \(buildFlags : BuildFlags)
      ->  merge
            { None = [] : List Text
            , Instrumented = [ "DUNE_INSTRUMENT_WITH=bisect_ppx" ]
            }
            buildFlags

let toSuffixUppercase =
          \(buildFlags : BuildFlags)
      ->  merge { None = "", Instrumented = "Instrumented" } buildFlags

let toSuffixLowercase =
          \(buildFlags : BuildFlags)
      ->  merge { None = "", Instrumented = "instrumented" } buildFlags

let toLabelSegment =
          \(buildFlags : BuildFlags)
      ->  merge { None = "", Instrumented = "-instrumented" } buildFlags

in  { Type = BuildFlags
    , capitalName = capitalName
    , lowerName = lowerName
    , buildEnvs = buildEnvs
    , toSuffixUppercase = toSuffixUppercase
    , toSuffixLowercase = toSuffixLowercase
    , toLabelSegment = toLabelSegment
    }
