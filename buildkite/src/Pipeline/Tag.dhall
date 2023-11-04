-- Tag defines pipeline 
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline 

let Prelude = ../External/Prelude.dhall
let List/any = Prelude.List.any

let Tag : Type = < Fast | Long | VeryLong | TearDown | Lint | Release | Test | Toolchain  >

let toNatural: Tag -> Natural = \(tag: Tag) -> 
  merge {
    Fast = 1
    , Long = 2
    , VeryLong = 3
    , TearDown = 4
    , Lint = 5
    , Release = 6
    , Test = 7
    , Toolchain = 8
  } tag

let equal: Tag -> Tag -> Bool = \(left: Tag) -> \(right: Tag) ->
  Prelude.Natural.equal (toNatural left) (toNatural right) 


let hasAny: Tag -> List Tag -> Bool = \(input: Tag) -> \(tags: List Tag) ->
  List/any Tag (\(x: Tag) -> equal x input ) tags

let contains: List Tag -> List Tag -> Bool = \(input: List Tag) -> \(tags: List Tag) ->
  List/any Tag (\(x: Tag) -> hasAny x tags ) input

let capitalName = \(tag : Tag) ->
  merge {
    Fast = "Fast"
    , Long = "Long"
    , VeryLong = "VeryLong"
    , TearDown = "TearDown"
    , Lint = "Lint"
    , Release = "Release"
    , Test = "Test"
    , Toolchain = "Toolchain" 
  } tag

let lowerName = \(tag : Tag) ->
  merge {
    Fast = "fast"
    , Long = "long"
    , VeryLong = "veryLong"
    , TearDown = "tearDown"
    , Lint = "lint"
    , Release = "release"
    , Test = "test" 
    , Toolchain = "toolchain"
  } tag


in
{ 
  Type = Tag,
  capitalName = capitalName,
  lowerName = lowerName,
  toNatural = toNatural,
  equal = equal,
  hasAny = hasAny,
  contains = contains
}