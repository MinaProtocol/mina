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
      | HardforkPackageGeneration
      | Promote
      | DebianBuild
      | DockerBuild
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
            , AllTests =
              [ Tag.Type.Lint
              , Tag.Type.Release
              , Tag.Type.Test
              , Tag.Type.Hardfork
              ]
            , Release = [ Tag.Type.Release ]
            , Promote = [ Tag.Type.Promote ]
            , HardforkPackageGeneration = [ Tag.Type.Hardfork ]
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
            , HardforkPackageGeneration = "HardforkPackageGeneration"
            }
            filter

in  { Type = Filter, tags = tags, show = show }
