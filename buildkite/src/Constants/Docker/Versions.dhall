let Profiles = ../Artifact/Profiles.dhall

let Pkg = ./Package.dhall

let Network = ../Network.dhall

let DebianVersions = ../Debian/Versions.dhall

let BuildFlags = ../Artifact/BuildFlags.dhall

let Arch = ../Artifact/Arch.dhall

let Docker
    : Type
    = < Bookworm | Bullseye | Jammy | Focal | Noble >

let capitalName =
          \(docker : Docker)
      ->  merge
            { Bookworm = "Bookworm"
            , Bullseye = "Bullseye"
            , Jammy = "Jammy"
            , Focal = "Focal"
            , Noble = "Noble"
            }
            docker

let lowerName =
          \(docker : Docker)
      ->  merge
            { Bookworm = "bookworm"
            , Bullseye = "bullseye"
            , Jammy = "jammy"
            , Focal = "focal"
            , Noble = "noble"
            }
            docker

let DepsSpec =
      { Type =
          { codename : Docker
          , prefix : Text
          , network : Network.Type
          , profile : Profiles.Type
          , artifact : Pkg.Type
          , buildFlags : BuildFlags.Type
          , arch : Arch.Type
          , suffix : Text
          }
      , default =
          { codename = Docker.Bullseye
          , prefix = "MinaArtifact"
          , network = Network.Type.Devnet
          , profile = Profiles.Type.Devnet
          , artifact = Pkg.Type.Daemon { network = Network.Type.Devnet }
          , buildFlags = BuildFlags.Type.None
          , suffix = "docker-image"
          , arch = Arch.Type.Amd64
          }
      }

let dependsOn =
          \(spec : DepsSpec.Type)
      ->  let key =
                "${Pkg.lowerName
                     spec.artifact}-${Network.lowerName
                                        spec.network}-${spec.suffix}"

          let buildFlagSuffix =
                merge
                  { None = ""
                  , Instrumented =
                      "${BuildFlags.toSuffixUppercase spec.buildFlags}"
                  }
                  spec.buildFlags

          let archSuffix = merge { Amd64 = "", Arm64 = "Arm64" } spec.arch

          in  [ { name =
                    "${spec.prefix}${Network.namePrefixSegment
                                       spec.network}${capitalName
                                                        spec.codename}${buildFlagSuffix}${archSuffix}"
                , key = key
                }
              ]

let ofDebian =
          \(debian : DebianVersions.DebVersion)
      ->  merge
            { Bookworm = Docker.Bookworm
            , Bullseye = Docker.Bullseye
            , Jammy = Docker.Jammy
            , Focal = Docker.Focal
            , Noble = Docker.Noble
            }
            debian

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , ofDebian = ofDebian
    , dependsOn = dependsOn
    , DepsSpec = DepsSpec
    }
