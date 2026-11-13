-- Tag defines pipeline
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclude in pipeline

let Tag = ./Tag.dhall

let Filter
    : Type
    = < FastOnly
      | Long
      | LongAndVeryLong
      | TearDownOnly
      | ToolchainsOnly
      | BaseDockersOnly
      | AllTests
      | Release
      | DebianBuild
      | DockerBuild
      | Packaging
      | Publish
      | PackagingAmd64Devnet
      | PackagingAmd64Mainnet
      | PackagingAmd64Generic
      | PackagingArm64Lightnet
      | PublishArm64Lightnet
      | Rosetta
      | Hardfork
      | AllDockersAndDebians
      | DockerBuildArm64
      | DockerBuildAmd64
      | DockerBuildArm64Devnet
      | DockerBuildArm64DevnetNoble
      | DockerBuildArm64DevnetBookworm
      | DockerBuildAmd64Devnet
      | DockerBuildAmd64DevnetNoble
      | DockerBuildAmd64DevnetJammy
      | DockerBuildAmd64DevnetBookworm
      | DockerBuildAmd64DevnetBullseye
      | DockerBuildAmd64DevnetFocal
      | DockerBuildArm64Mainnet
      | DockerBuildArm64MainnetNoble
      | DockerBuildArm64MainnetBookworm
      | DockerBuildAmd64Mainnet
      | DockerBuildAmd64MainnetNoble
      | DockerBuildAmd64MainnetJammy
      | DockerBuildAmd64MainnetBookworm
      | DockerBuildAmd64MainnetBullseye
      | DockerBuildAmd64MainnetFocal
      | DockerBuildArm64Lightnet
      | DockerBuildAmd64LightnetBookworm
      | DockerBuildAmd64LightnetBullseye
      | DockerBuildAmd64Lightnet
      | DockerBuildArm64LightnetBookworm
      >

let tags
    : Filter -> List Tag.Type
    =
      -- PackagingArm64Lightnet: the Bookworm arm64 packages that the
      -- mina-lightnet-docker images install, the lightnet (no proofs) and the
      -- devnet (full proofs) image alike: mina-devnet-generic,
      -- mina-archive-devnet, mina-logproc and their mina dependencies. With
      -- FILTER_MODE=All it selects the generic and devnet Bookworm arm64
      -- packaging jobs: the arm64 apps job has no Packaging tag, and the
      -- mainnet one no Devnet tag.
      --
      -- PublishArm64Lightnet: its own tag, not Publish. The amd64 publish
      -- pipelines select Publish in Any mode and would run an arm64 publish
      -- too. See Jobs/Release/PublishDebiansArm64Lightnet.dhall.
          \(filter : Filter)
      ->  merge
            { FastOnly = [ Tag.Type.Fast ]
            , LongAndVeryLong = [ Tag.Type.Long, Tag.Type.VeryLong ]
            , Long = [ Tag.Type.Long ]
            , TearDownOnly = [ Tag.Type.TearDown ]
            , ToolchainsOnly = [ Tag.Type.Toolchain ]
            , BaseDockersOnly = [ Tag.Type.Base ]
            , DebianBuild = [ Tag.Type.Debian ]
            , DockerBuild = [ Tag.Type.Docker ]
            , Packaging = [ Tag.Type.Packaging ]
            , Publish = [ Tag.Type.Publish ]
            , PackagingAmd64Devnet =
              [ Tag.Type.Packaging, Tag.Type.Devnet, Tag.Type.Amd64 ]
            , PackagingAmd64Mainnet =
              [ Tag.Type.Packaging, Tag.Type.Mainnet, Tag.Type.Amd64 ]
            , PackagingAmd64Generic =
              [ Tag.Type.Packaging, Tag.Type.Generic, Tag.Type.Amd64 ]
            , PackagingArm64Lightnet =
              [ Tag.Type.Packaging
              , Tag.Type.Devnet
              , Tag.Type.Arm64
              , Tag.Type.Bookworm
              ]
            , PublishArm64Lightnet = [ Tag.Type.PublishArm64 ]
            , AllTests = [ Tag.Type.Lint, Tag.Type.Release, Tag.Type.Test ]
            , Release = [ Tag.Type.Release ]
            , Rosetta = [ Tag.Type.Rosetta ]
            , Hardfork = [ Tag.Type.Hardfork ]
            , AllDockersAndDebians =
              [ Tag.Type.Docker
              , Tag.Type.Debian
              , Tag.Type.Arm64
              , Tag.Type.Amd64
              , Tag.Type.Noble
              , Tag.Type.Jammy
              , Tag.Type.Bookworm
              , Tag.Type.Bullseye
              , Tag.Type.Focal
              , Tag.Type.Devnet
              , Tag.Type.Mainnet
              , Tag.Type.Lightnet
              , Tag.Type.Release
              ]
            , DockerBuildArm64 = [ Tag.Type.Docker, Tag.Type.Arm64 ]
            , DockerBuildAmd64 = [ Tag.Type.Docker, Tag.Type.Amd64 ]
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
            , DockerBuildArm64DevnetNoble =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Arm64
              , Tag.Type.Noble
              ]
            , DockerBuildAmd64DevnetNoble =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Amd64
              , Tag.Type.Noble
              ]
            , DockerBuildArm64MainnetNoble =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Arm64
              , Tag.Type.Noble
              ]
            , DockerBuildAmd64MainnetNoble =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Amd64
              , Tag.Type.Noble
              ]
            , DockerBuildAmd64DevnetJammy =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Amd64
              , Tag.Type.Jammy
              ]
            , DockerBuildAmd64MainnetJammy =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Amd64
              , Tag.Type.Jammy
              ]
            , DockerBuildArm64DevnetBookworm =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Arm64
              , Tag.Type.Bookworm
              ]
            , DockerBuildAmd64DevnetBookworm =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Amd64
              , Tag.Type.Bookworm
              ]
            , DockerBuildArm64MainnetBookworm =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Arm64
              , Tag.Type.Bookworm
              ]
            , DockerBuildAmd64MainnetBookworm =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Amd64
              , Tag.Type.Bookworm
              ]
            , DockerBuildArm64LightnetBookworm =
              [ Tag.Type.Docker
              , Tag.Type.Lightnet
              , Tag.Type.Arm64
              , Tag.Type.Bookworm
              ]
            , DockerBuildAmd64LightnetBookworm =
              [ Tag.Type.Docker
              , Tag.Type.Lightnet
              , Tag.Type.Amd64
              , Tag.Type.Bookworm
              ]
            , DockerBuildAmd64DevnetBullseye =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Amd64
              , Tag.Type.Bullseye
              ]
            , DockerBuildAmd64MainnetBullseye =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Amd64
              , Tag.Type.Bullseye
              ]
            , DockerBuildAmd64LightnetBullseye =
              [ Tag.Type.Docker
              , Tag.Type.Lightnet
              , Tag.Type.Amd64
              , Tag.Type.Bullseye
              ]
            , DockerBuildAmd64DevnetFocal =
              [ Tag.Type.Docker
              , Tag.Type.Devnet
              , Tag.Type.Amd64
              , Tag.Type.Focal
              ]
            , DockerBuildAmd64MainnetFocal =
              [ Tag.Type.Docker
              , Tag.Type.Mainnet
              , Tag.Type.Amd64
              , Tag.Type.Focal
              ]
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
            , BaseDockersOnly = "BaseDockersOnly"
            , TearDownOnly = "TearDownOnly"
            , AllTests = "AllTests"
            , Release = "Release"
            , DebianBuild = "DebianBuild"
            , DockerBuild = "DockerBuild"
            , Packaging = "Packaging"
            , Publish = "Publish"
            , PackagingAmd64Devnet = "PackagingAmd64Devnet"
            , PackagingAmd64Mainnet = "PackagingAmd64Mainnet"
            , PackagingAmd64Generic = "PackagingAmd64Generic"
            , PackagingArm64Lightnet = "PackagingArm64Lightnet"
            , PublishArm64Lightnet = "PublishArm64Lightnet"
            , Rosetta = "Rosetta"
            , Hardfork = "Hardfork"
            , AllDockersAndDebians = "AllDockersAndDebians"
            , DockerBuildArm64 = "DockerBuildArm64"
            , DockerBuildAmd64 = "DockerBuildAmd64"
            , DockerBuildArm64Devnet = "DockerBuildArm64Devnet"
            , DockerBuildAmd64Devnet = "DockerBuildAmd64Devnet"
            , DockerBuildArm64Mainnet = "DockerBuildArm64Mainnet"
            , DockerBuildAmd64Mainnet = "DockerBuildAmd64Mainnet"
            , DockerBuildArm64Lightnet = "DockerBuildArm64Lightnet"
            , DockerBuildAmd64Lightnet = "DockerBuildAmd64Lightnet"
            , DockerBuildArm64DevnetNoble = "DockerBuildArm64DevnetNoble"
            , DockerBuildAmd64DevnetNoble = "DockerBuildAmd64DevnetNoble"
            , DockerBuildArm64MainnetNoble = "DockerBuildArm64MainnetNoble"
            , DockerBuildAmd64MainnetNoble = "DockerBuildAmd64MainnetNoble"
            , DockerBuildAmd64DevnetJammy = "DockerBuildAmd64DevnetJammy"
            , DockerBuildAmd64MainnetJammy = "DockerBuildAmd64MainnetJammy"
            , DockerBuildArm64DevnetBookworm = "DockerBuildArm64DevnetBookworm"
            , DockerBuildAmd64DevnetBookworm = "DockerBuildAmd64DevnetBookworm"
            , DockerBuildArm64MainnetBookworm =
                "DockerBuildArm64MainnetBookworm"
            , DockerBuildAmd64MainnetBookworm =
                "DockerBuildAmd64MainnetBookworm"
            , DockerBuildArm64LightnetBookworm =
                "DockerBuildArm64LightnetBookworm"
            , DockerBuildAmd64LightnetBookworm =
                "DockerBuildAmd64LightnetBookworm"
            , DockerBuildAmd64DevnetBullseye = "DockerBuildAmd64DevnetBullseye"
            , DockerBuildAmd64MainnetBullseye =
                "DockerBuildAmd64MainnetBullseye"
            , DockerBuildAmd64LightnetBullseye =
                "DockerBuildAmd64LightnetBullseye"
            , DockerBuildAmd64DevnetFocal = "DockerBuildAmd64DevnetFocal"
            , DockerBuildAmd64MainnetFocal = "DockerBuildAmd64MainnetFocal"
            }
            filter

in  { Type = Filter, tags = tags, show = show }
