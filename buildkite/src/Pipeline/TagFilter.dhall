-- Tag defines pipeline
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline

let Tag = ./Tag.dhall

let Filter
    : Type
    = < FastOnly
      | Long
      | LongAndVeryLong
      | TearDownOnly
      | ToolchainsOnly
      | AllTests
      | Release
      | Promote
      | DebianBuild
      | DockerBuild
      | Rosetta
      | DockerBuildArm64Devnet
      | DockerBuildAmd64Devnet
      | DockerBuildArm64Mainnet
      | DockerBuildAmd64Mainnet
      | DockerBuildArm64Lightnet
      | DockerBuildAmd64Lightnet
      >

let tags
    : Filter -> List Tag.Type
    =     \(filter : Filter)
      ->  merge
            { FastOnly = [ Tag.Type.Fast ]
            , LongAndVeryLong = [ Tag.Type.Long, Tag.Type.VeryLong ]
            , Long = [ Tag.Type.Long ]
            , TearDownOnly = [ Tag.Type.TearDown ]
            , ToolchainsOnly = [ Tag.Type.Toolchain ]
            , DebianBuild = [ Tag.Type.Debian ]
            , DockerBuild = [ Tag.Type.Docker ]
            , AllTests = [ Tag.Type.Lint, Tag.Type.Release, Tag.Type.Test ]
            , Release = [ Tag.Type.Release ]
            , Promote = [ Tag.Type.Promote ]
            , Rosetta = [ Tag.Type.Rosetta ]
            , DockerBuildArm64Devnet =
              [ Tag.Type.Docker, Tag.Type.Devnet, Tag.Type.Arm64 ]
            , DockerBuildAmd64Devnet =
              [ Tag.Type.Docker, Tag.Type.Devnet, Tag.Type.Amd64 ]
            , DockerBuildArm64Mainnet =
              [ Tag.Type.Docker, Tag.Type.Mainnet, Tag.Type.Arm64 ]
            , DockerBuildAmd64Mainnet =
              [ Tag.Type.Docker, Tag.Type.Mainnet, Tag.Type.Amd64 ]
            , DockerBuildArm64Lightnet =
              [ Tag.Type.Docker, Tag.Type.Lightnet, Tag.Type.Arm64 ]
            , DockerBuildAmd64Lightnet =
              [ Tag.Type.Docker, Tag.Type.Lightnet, Tag.Type.Amd64 ]
            }
            filter

let show
    : Filter -> Text
    =     \(filter : Filter)
      ->  merge
            { FastOnly = "FastOnly"
            , LongAndVeryLong = "LongAndVeryLong"
            , Long = "Long"
            , ToolchainsOnly = "Toolchain"
            , TearDownOnly = "TearDownOnly"
            , AllTests = "AllTests"
            , Release = "Release"
            , Promote = "Promote"
            , DebianBuild = "DebianBuild"
            , DockerBuild = "DockerBuild"
            , Rosetta = "Rosetta"
            , DockerBuildArm64Devnet = "DockerBuildArm64Devnet"
            , DockerBuildAmd64Devnet = "DockerBuildAmd64Devnet"
            , DockerBuildArm64Mainnet = "DockerBuildArm64Mainnet"
            , DockerBuildAmd64Mainnet = "DockerBuildAmd64Mainnet"
            , DockerBuildArm64Lightnet = "DockerBuildArm64Lightnet"
            , DockerBuildAmd64Lightnet = "DockerBuildAmd64Lightnet"
            }
            filter

in  { Type = Filter, tags = tags, show = show }
