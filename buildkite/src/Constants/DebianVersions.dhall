let Prelude = ../External/Prelude.dhall

let Optional/default = Prelude.Optional.default

let Profiles = ./Profiles.dhall

let BuildFlags = ./BuildFlags.dhall

let S = ../Lib/SelectFiles.dhall

let DebVersion = < Bookworm | Bullseye | Jammy | Focal >

let capitalName =
          \(debVersion : DebVersion)
      ->  merge
            { Bookworm = "Bookworm"
            , Bullseye = "Bullseye"
            , Jammy = "Jammy"
            , Focal = "Focal"
            }
            debVersion

let lowerName =
          \(debVersion : DebVersion)
      ->  merge
            { Bookworm = "bookworm"
            , Bullseye = "bullseye"
            , Jammy = "jammy"
            , Focal = "focal"
            }
            debVersion

let dependsOnStep =
          \(prefix : Optional Text)
      ->  \(debVersion : DebVersion)
      ->  \(profile : Profiles.Type)
      ->  \(buildFlag : BuildFlags.Type)
      ->  \(step : Text)
      ->  let profileSuffix = Profiles.toSuffixUppercase profile

          let prefix = Optional/default Text "MinaArtifact" prefix

          in  merge
                { Bookworm =
                  [ { name =
                        "${prefix}${profileSuffix}${BuildFlags.toSuffixUppercase
                                                      buildFlag}"
                    , key = "${step}-deb-pkg"
                    }
                  ]
                , Bullseye =
                  [ { name =
                        "${prefix}${capitalName
                                      debVersion}${profileSuffix}${BuildFlags.toSuffixUppercase
                                                                     buildFlag}"
                    , key = "${step}-deb-pkg"
                    }
                  ]
                , Jammy =
                  [ { name =
                        "${prefix}${capitalName
                                      debVersion}${profileSuffix}${BuildFlags.toSuffixUppercase
                                                                     buildFlag}"
                    , key = "${step}-deb-pkg"
                    }
                  ]
                , Focal =
                  [ { name =
                        "${prefix}${capitalName
                                      debVersion}${profileSuffix}${BuildFlags.toSuffixUppercase
                                                                     buildFlag}"
                    , key = "${step}-deb-pkg"
                    }
                  ]
                }
                debVersion

let dependsOn =
          \(debVersion : DebVersion)
      ->  \(profile : Profiles.Type)
      ->  dependsOnStep
            (None Text)
            debVersion
            profile
            BuildFlags.Type.None
            "build"

let minimalDirtyWhen =
      [ S.exactly "buildkite/src/Constants/DebianVersions" "dhall"
      , S.exactly "buildkite/src/Constants/ContainerImages" "dhall"
      , S.exactly "buildkite/src/Command/HardforkPackageGeneration" "dhall"
      , S.exactly "buildkite/src/Command/MinaArtifact" "dhall"
      , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact")
      , S.strictlyStart (S.contains "dockerfiles/stages")
      , S.exactly "scripts/debian/build" "sh"
      , S.exactly "scripts/debian/builder-helpers" "sh"
      , S.exactly "scripts/docker/release" "sh"
      , S.exactly "scripts/docker/build" "sh"
      , S.exactly "buildkite/scripts/build-artifact" "sh"
      , S.exactly "buildkite/scripts/build-hardfork-package" "sh"
      , S.exactly "buildkite/scripts/check-compatibility" "sh"
      , S.exactly "scripts/snark_transaction_profiler" "py"
      , S.exactly "buildkite/scripts/version-linter" "sh"
      , S.exactly "scripts/version-linter" "py"
      ]

let bullseyeDirtyWhen =
        [ S.strictlyStart (S.contains "src")
        , S.strictlyStart (S.contains "automation")
        , S.strictly (S.contains "Makefile")
        , S.exactly "buildkite/scripts/connect-to-berkeley" "sh"
        , S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh"
        , S.exactly "buildkite/scripts/rosetta-integration-tests" "sh"
        , S.exactly "buildkite/scripts/rosetta-integration-tests-full" "sh"
        , S.exactly "buildkite/scripts/rosetta-integration-tests-fast" "sh"
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
            }
            debVersion

in  { DebVersion = DebVersion
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    , dependsOnStep = dependsOnStep
    , dirtyWhen = dirtyWhen
    }
