let Profiles = ./Profiles.dhall

let Network = ./Network.dhall

let BuildFlags = ./BuildFlags.dhall

let Arch = ./Arch.dhall

let S = ../Lib/SelectFiles.dhall

let DebVersion = < Bookworm | Bullseye | Jammy | Focal | Noble >

let capitalName =
          \(debVersion : DebVersion)
      ->  merge
            { Bookworm = "Bookworm"
            , Bullseye = "Bullseye"
            , Jammy = "Jammy"
            , Focal = "Focal"
            , Noble = "Noble"
            }
            debVersion

let lowerName =
          \(debVersion : DebVersion)
      ->  merge
            { Bookworm = "bookworm"
            , Bullseye = "bullseye"
            , Jammy = "jammy"
            , Focal = "focal"
            , Noble = "noble"
            }
            debVersion

let DepsSpec =
      { Type =
          { deb_version : DebVersion
          , network : Network.Type
          , profile : Profiles.Type
          , build_flag : BuildFlags.Type
          , step : Text
          , prefix : Text
          , arch : Arch.Type
          }
      , default =
          { deb_version = DebVersion.Bullseye
          , network = Network.Type.Berkeley
          , profile = Profiles.Type.Devnet
          , build_flag = BuildFlags.Type.None
          , step = "build"
          , prefix = "MinaArtifact"
          , arch = Arch.Type.Amd64
          }
      }

let dependsOn =
          \(spec : DepsSpec.Type)
      ->  let profileSuffix = Profiles.toSuffixUppercase spec.profile

          let name =
                "${spec.prefix}${capitalName
                                   spec.deb_version}${Network.capitalName
                                                        spec.network}${profileSuffix}${BuildFlags.toSuffixUppercase
                                                                                         spec.build_flag}${Arch.nameSuffix
                                                                                                             spec.arch}"

          in  [ { name = name, key = "${spec.step}-deb-pkg" } ]

let minimalDirtyWhen =
      [ S.exactly "buildkite/src/Constants/DebianVersions" "dhall"
      , S.exactly "buildkite/src/Constants/ContainerImages" "dhall"
      , S.exactly "buildkite/src/Command/MinaArtifact" "dhall"
      , S.exactly "buildkite/src/Command/PatchArchiveTest" "dhall"
      , S.exactly "buildkite/src/Command/ArchiveNodeTest" "dhall"
      , S.exactly "buildkite/src/Command/Bench/Base" "dhall"
      , S.strictlyStart (S.contains "scripts/benchmarks")
      , S.strictlyStart (S.contains "buildkite/scripts/bench")
      , S.exactly "buildkite/src/Command/ReplayerTest" "dhall"
      , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact")
      , S.strictlyStart (S.contains "dockerfiles/stages")
      , S.strictlyStart (S.contains "dockerfiles")
      , S.strictlyStart (S.contains "scripts/debian")
      , S.strictlyStart (S.contains "scripts/docker")
      , S.exactly "buildkite/scripts/build-artifact" "sh"
      , S.exactly "buildkite/scripts/check-compatibility" "sh"
      , S.exactly "buildkite/scripts/version-linter" "sh"
      , S.exactly "scripts/version-linter" "py"
      , S.exactly
          "buildkite/scripts/version-linter-patch-missing-type-shapes"
          "sh"
      ]

let bullseyeDirtyWhen =
        [ S.strictlyStart (S.contains "src")
        , S.strictly (S.contains "Makefile")
        , S.exactly "buildkite/scripts/connect/connect-to-network" "sh"
        , S.exactly "buildkite/scripts/tests/rosetta-integration-tests" "sh"
        , S.exactly "scripts/patch-archive-test" "sh"
        , S.strictlyStart (S.contains "buildkite/src/Jobs/Test")
        ]
      # minimalDirtyWhen

let dirtyWhen =
          \(debVersion : DebVersion)
      ->  merge
            { Bookworm = minimalDirtyWhen
            , Bullseye = bullseyeDirtyWhen
            , Jammy = minimalDirtyWhen
            , Focal = minimalDirtyWhen
            , Noble = minimalDirtyWhen
            }
            debVersion

in  { DebVersion = DebVersion
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    , dirtyWhen = dirtyWhen
    , DepsSpec = DepsSpec
    }
