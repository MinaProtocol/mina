-- Tag defines pipeline
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline

let Prelude = ../External/Prelude.dhall

let Extensions = ../Lib/Extensions.dhall

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
      | Archive
      | Mesa
      >

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
            , Archive = "Archive"
            , Mesa = "Mesa"
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
            , Archive = "archive"
            , Mesa = "mesa"
            }
            tag

let join =
          \(tags : List Tag)
      ->  Extensions.join "," (Prelude.List.map Tag Text lowerName tags)

in  { Type = Tag
    , capitalName = capitalName
    , lowerName = lowerName
    , join = join
    }
