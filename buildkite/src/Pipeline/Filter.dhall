-- Tag defines pipeline 
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline 

let Prelude = ../External/Prelude.dhall
let Tag = ./Tag.dhall

let Filter : Type = < FastOnly | Long | LongAndVeryLong | TearDownOnly | AllTests >

let tags: Filter -> List Tag.Type = \(filter: Filter) -> 
  merge {
    FastOnly = [ Tag.Type.Fast ]
    , LongAndVeryLong = [ Tag.Type.Long, Tag.Type.VeryLong ]
    , Long = [ Tag.Type.Long ]
    , TearDownOnly = [ Tag.Type.TearDown ]
    , AllTests = [ Tag.Type.Lint, Tag.Type.Release, Tag.Type.Test, Tag.Type.Fast]
  } filter

let show: Filter -> Text = \(filter: Filter) -> 
  merge {
    FastOnly = "FastOnly"
    , LongAndVeryLong = "LongAndVeryLong"
    , Long = "Long"
    , TearDownOnly = "TearDownOnly"
    , AllTests = "AllTests"
  } filter

in
{ 
  Type = Filter,
  tags = tags,
  show = show
}