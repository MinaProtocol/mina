let Profiles = ./Profiles.dhall

let Network = ./Network.dhall

let BuildFlags = ./BuildFlags.dhall

let Arch = ./Arch.dhall

let S = ../Lib/SelectFiles.dhall

let DebVersion = < Bookworm | Bullseye | Jammy | Focal | Noble | Trixie >

let capitalName =
          \(debVersion : DebVersion)
      ->  merge
            { Bookworm = "Bookworm"
            , Bullseye = "Bullseye"
            , Jammy = "Jammy"
            , Focal = "Focal"
            , Noble = "Noble"
            , Trixie = "Trixie"
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
            , Trixie = "trixie"
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
          , network = Network.Type.Devnet
          , profile = Profiles.Type.Devnet
          , build_flag = BuildFlags.Type.None
          , step = "build"
          , prefix = "MinaArtifact"
          , arch = Arch.Type.Amd64
          }
      }

let dependsOn =
          \(spec : DepsSpec.Type)
      ->  let name =
                "${spec.prefix}${Network.namePrefixSegment
                                   spec.network}${capitalName
                                                    spec.deb_version}${BuildFlags.toSuffixUppercase
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
      , S.strictlyStart (S.contains "buildkite/scripts/bench")
      , S.exactly "buildkite/src/Command/ReplayerTest" "dhall"
      , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact")
      , S.strictlyStart (S.contains "dockerfiles/toolchain")
      , S.strictlyStart (S.contains "dockerfiles")
      , S.strictlyStart (S.contains "scripts/debian")
      , S.strictlyStart (S.contains "scripts/docker")
      , S.exactly "buildkite/scripts/build-artifact" "sh"
      , S.exactly "buildkite/scripts/version-linter" "sh"
      , S.exactly "buildkite/scripts/apps/write_to_cache" "sh"
      , S.strictlyStart (S.contains "buildkite/scripts/tests")
      , S.strictlyStart (S.contains "scripts/rosetta")
      , S.exactly "scripts/rosetta/test-block-race" "sh"
      , S.exactly "scripts/version-linter" "py"
      , S.strictlyStart (S.contains "src/test")
      , S.exactly
          "buildkite/scripts/version-linter-patch-missing-type-shapes"
          "sh"
      ]

let bullseyeDirtyWhen =
        [ S.strictlyStart (S.contains "src")
        , S.strictly (S.contains "Makefile")
        , S.exactly "buildkite/scripts/connect/connect-to-network" "sh"
        , S.strictlyStart (S.contains "buildkite/scripts/tests/rosetta")
        , S.exactly "scripts/patch-archive-test" "sh"
        , S.exactly "buildkite/scripts/single-node-tests" "sh"
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
            , Trixie = minimalDirtyWhen
            }
            debVersion

let packageDirtyWhen =
    -- Strictly what a packaging job reads or produces: the .deb and docker
    -- build scripts, the Dockerfiles, and the Dhall that defines the jobs.
    --
    -- It deliberately does NOT list the compile (buildkite/scripts/build-artifact.sh
    -- and the apps-cache writers) -- packaging never runs those, it restores the
    -- tree the app build already produced. The only apps script it touches is
    -- restore_build_tree.sh, via buildkite/scripts/debian/build-from-cache.sh.
    --
    -- Nor does it list the packaging TESTS. Those used to be here so that a test
    -- selected by its own dirty-when would not be left with a dangling
    -- dependency on a packaging job that had not been selected. monorepo.sh
    -- resolves dependencies itself now (phase 2): selecting DebianUpgradeTest
    -- pulls MinaArtifactBullseye in regardless of this list, so listing the
    -- tests here only made packaging run on changes it does not depend on.
      [ S.exactly "buildkite/src/Constants/DebianVersions" "dhall"
      , S.exactly "buildkite/src/Constants/ContainerImages" "dhall"
      , S.exactly "buildkite/src/Command/MinaArtifact" "dhall"
      , S.exactly "buildkite/src/Command/DockerImage" "dhall"
      , S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact")
      , S.strictlyStart (S.contains "dockerfiles")
      , S.strictlyStart (S.contains "scripts/debian")
      , S.strictlyStart (S.contains "scripts/docker")
      , S.strictlyStart (S.contains "scripts/hardfork")
      , S.strictlyStart (S.contains "buildkite/scripts/docker")
      , S.strictlyStart (S.contains "buildkite/scripts/debian")
      , S.exactly "buildkite/scripts/apps/restore_build_tree" "sh"
      , S.strictlyStart (S.contains "buildkite/scripts/cache")
      ]

let appDependsOn =
    -- spec.network and spec.profile are deliberately NOT part of the name. An
    -- app build compiles the whole tree and its binaries carry no network (see
    -- AppsSpec in Command/MinaArtifact.dhall), so there is exactly one app job
    -- per codename/build-flag/arch and every consumer of it, whatever network
    -- it packages or tests afterwards, waits on that one job. Naming a network
    -- here used to mint a second, identical app job per network, which
    -- recompiled the tree and then raced the first one writing the same
    -- binaries into the same apps cache directory.
          \(spec : DepsSpec.Type)
      ->  let name =
                "${spec.prefix}${capitalName
                                   spec.deb_version}${BuildFlags.toSuffixUppercase
                                                        spec.build_flag}${Arch.nameSuffix
                                                                            spec.arch}Apps"

          in  [ { name = name, key = "build-apps" } ]

let overrideEnvs = [ "OVERRIDE_TAG", "OVERRIDE_GITHASH", "SKIP_GITBRANCH" ]

in  { DebVersion = DebVersion
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    , appDependsOn = appDependsOn
    , dirtyWhen = dirtyWhen
    , packageDirtyWhen = packageDirtyWhen
    , DepsSpec = DepsSpec
    , overrideEnvs = overrideEnvs
    }
