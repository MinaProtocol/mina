let Prelude = ../External/Prelude.dhall

let Optional/default = Prelude.Optional.default

let Profiles = ./Profiles.dhall

let Network = ./Network.dhall

let BuildFlags = ./BuildFlags.dhall

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

let dependsOnStep =
          \(prefix : Optional Text)
      ->  \(debVersion : DebVersion)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(buildFlag : BuildFlags.Type)
      ->  \(step : Text)
      ->  let profileSuffix = Profiles.toSuffixUppercase profile

          let prefix = Optional/default Text "MinaArtifact" prefix

          let name =
                "${prefix}${capitalName
                              debVersion}${Network.capitalName
                                             network}${profileSuffix}${BuildFlags.toSuffixUppercase
                                                                         buildFlag}"

          in  merge
                { Bookworm = [ { name = name, key = "${step}-deb-pkg" } ]
                , Bullseye = [ { name = name, key = "${step}-deb-pkg" } ]
                , Jammy = [ { name = name, key = "${step}-deb-pkg" } ]
                , Focal = [ { name = name, key = "${step}-deb-pkg" } ]
                , Noble = [ { name = name, key = "${step}-deb-pkg" } ]
                }
                debVersion

let dependsOn =
          \(debVersion : DebVersion)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  dependsOnStep
            (None Text)
            debVersion
            network
            profile
            BuildFlags.Type.None
            "build"

let minimalDirtyWhen =
      [ S.exactly "buildkite/src/Constants/DebianVersions" "dhall"
      , S.exactly "buildkite/src/Constants/ContainerImages" "dhall"
      , S.exactly "buildkite/src/Command/MinaArtifact" "dhall"
      , S.exactly "buildkite/src/Command/PatchArchiveTest" "dhall"
      , S.exactly "buildkite/src/Command/Bench/Base" "dhall"
      , S.strictlyStart (S.contains "scripts/benchmarks")
      , S.strictlyStart (S.contains "buildkite/scripts/bench")
      , S.exactly "buildkite/src/Command/ReplayerTest" "dhall"
      , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact")
      , S.strictlyStart (S.contains "dockerfiles/stages")
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
        , S.strictlyStart (S.contains "automation")
        , S.strictly (S.contains "Makefile")
        , S.exactly "buildkite/scripts/connect/connect-to-network" "sh"
        , S.exactly "buildkite/scripts/rosetta-integration-tests" "sh"
        , S.exactly "buildkite/scripts/rosetta-integration-tests-full" "sh"
        , S.exactly "buildkite/scripts/rosetta-integration-tests-fast" "sh"
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
    , dependsOnStep = dependsOnStep
    , dirtyWhen = dirtyWhen
    }
