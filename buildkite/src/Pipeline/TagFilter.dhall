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
      | DockerBuildDevnetArm64
      | DockerBuildDevnetAmd64
      | DockerBuildMainnetArm64
      | DockerBuildMainnetAmd64
      | DockerBuildLightnetArm64
      | DockerBuildLightnetAmd64
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
            , DockerBuildDevnetArm64 =
              [ Tag.Type.Docker, Tag.Type.Devnet, Tag.Type.Arm64 ]
            , DockerBuildDevnetAmd64 =
              [ Tag.Type.Docker, Tag.Type.Devnet, Tag.Type.Amd64 ]
            , DockerBuildMainnetArm64 =
              [ Tag.Type.Docker, Tag.Type.Mainnet, Tag.Type.Arm64 ]
            , DockerBuildMainnetAmd64 =
              [ Tag.Type.Docker, Tag.Type.Mainnet, Tag.Type.Amd64 ]
            , DockerBuildLightnetArm64 =
              [ Tag.Type.Docker, Tag.Type.Lightnet, Tag.Type.Arm64 ]
            , DockerBuildLightnetAmd64 =
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
            , DockerBuildDevnetArm64 = "DockerBuildDevnetArm64"
            , DockerBuildDevnetAmd64 = "DockerBuildDevnetAmd64"
            , DockerBuildMainnetArm64 = "DockerBuildMainnetArm64"
            , DockerBuildMainnetAmd64 = "DockerBuildMainnetAmd64"
            , DockerBuildLightnetArm64 = "DockerBuildLightnetArm64"
            , DockerBuildLightnetAmd64 = "DockerBuildLightnetAmd64"
            }
            filter

in  { Type = Filter, tags = tags, show = show }
