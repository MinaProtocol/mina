-- Tag defines pipeline
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline

let Prelude = ../External/Prelude.dhall

let FilterMode = ./FilterMode.dhall

let List/any = Prelude.List.any

let List/all = Prelude.List.all

let Tag
    : Type
    = < Fast
      | Long
      | VeryLong
      | TearDown
      | Lint
      | Release
      | Test
      | Stable
      | Toolchain
      | Docker
      | Debian
      | Hardfork
      | Promote
      | Rosetta
      | Devnet
      | Lightnet
      | Arm64
      | Amd64
      | Mainnet
      | Bullseye
      | Bookworm
      | Noble
      | Focal
      | Jammy
      >

let toNatural
    : Tag -> Natural
    =     \(tag : Tag)
      ->  merge
            { Fast = 1
            , Long = 2
            , VeryLong = 3
            , TearDown = 4
            , Lint = 5
            , Release = 6
            , Test = 7
            , Toolchain = 8
            , Hardfork = 9
            , Stable = 10
            , Promote = 11
            , Debian = 12
            , Docker = 13
            , Rosetta = 14
            , Devnet = 15
            , Lightnet = 16
            , Arm64 = 17
            , Amd64 = 18
            , Mainnet = 19
            , Bullseye = 20
            , Bookworm = 21
            , Noble = 22
            , Focal = 23
            , Jammy = 24
            }
            tag

let equal
    : Tag -> Tag -> Bool
    =     \(left : Tag)
      ->  \(right : Tag)
      ->  Prelude.Natural.equal (toNatural left) (toNatural right)

let hasAny
    : Tag -> List Tag -> Bool
    =     \(input : Tag)
      ->  \(tags : List Tag)
      ->  List/any Tag (\(x : Tag) -> equal x input) tags

let hasAll
    : List Tag -> List Tag -> Bool
    =     \(input : List Tag)
      ->  \(tags : List Tag)
      ->  List/all Tag (\(x : Tag) -> hasAny x tags) input == True

let containsAll
    : List Tag -> List Tag -> Bool
    = \(input : List Tag) -> \(tags : List Tag) -> hasAll input tags

let containsAny
    : List Tag -> List Tag -> Bool
    =     \(input : List Tag)
      ->  \(tags : List Tag)
      ->  List/any Tag (\(x : Tag) -> hasAny x tags) input

let contains
    : List Tag -> List Tag -> FilterMode.Type -> Bool
    =     \(input : List Tag)
      ->  \(tags : List Tag)
      ->  \(filterMode : FilterMode.Type)
      ->  merge
            { Any = containsAny input tags, All = containsAll input tags }
            filterMode

let capitalName =
          \(tag : Tag)
      ->  merge
            { Fast = "Fast"
            , Long = "Long"
            , VeryLong = "VeryLong"
            , TearDown = "TearDown"
            , Lint = "Lint"
            , Release = "Release"
            , Test = "Test"
            , Toolchain = "Toolchain"
            , Hardfork = "Hardfork"
            , Stable = "Stable"
            , Promote = "Promote"
            , Docker = "Docker"
            , Debian = "Debian"
            , Rosetta = "Rosetta"
            , Devnet = "Devnet"
            , Lightnet = "Lightnet"
            , Arm64 = "Arm64"
            , Amd64 = "Amd64"
            , Mainnet = "Mainnet"
            , Bullseye = "Bullseye"
            , Bookworm = "Bookworm"
            , Noble = "Noble"
            , Focal = "Focal"
            , Jammy = "Jammy"
            }
            tag

let lowerName =
          \(tag : Tag)
      ->  merge
            { Fast = "fast"
            , Long = "long"
            , VeryLong = "veryLong"
            , TearDown = "tearDown"
            , Lint = "lint"
            , Release = "release"
            , Test = "test"
            , Toolchain = "toolchain"
            , Hardfork = "hardfork"
            , Stable = "stable"
            , Promote = "promote"
            , Docker = "docker"
            , Debian = "debian"
            , Rosetta = "rosetta"
            , Devnet = "devnet"
            , Lightnet = "lightnet"
            , Arm64 = "arm64"
            , Amd64 = "amd64"
            , Mainnet = "mainnet"
            , Bullseye = "bullseye"
            , Bookworm = "bookworm"
            , Noble = "noble"
            , Focal = "focal"
            , Jammy = "jammy"
            }
            tag

in  { Type = Tag
    , capitalName = capitalName
    , lowerName = lowerName
    , toNatural = toNatural
    , equal = equal
    , hasAny = hasAny
    , containsAny = containsAny
    , containsAll = containsAll
    , contains = contains
    }
