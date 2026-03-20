let Profiles = ./Profiles.dhall

let Artifacts = ./Artifacts.dhall

let Network = ./Network.dhall

let DebianVersions = ./DebianVersions.dhall

let BuildFlags = ./BuildFlags.dhall

let Arch = ./Arch.dhall

let Docker
    : Type
    = < Bookworm | Bullseye | Jammy | Focal | Noble | Trixie | Questing >

let capitalName =
          \(docker : Docker)
      ->  merge
            { Bookworm = "Bookworm"
            , Bullseye = "Bullseye"
            , Jammy = "Jammy"
            , Focal = "Focal"
            , Noble = "Noble"
            , Trixie = "Trixie"
            , Questing = "Questing"
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
            , Trixie = "trixie"
            , Questing = "questing"
            }
            docker

let DepsSpec =
      { Type =
          { codename : Docker
          , prefix : Text
          , network : Network.Type
          , profile : Profiles.Type
          , artifact : Artifacts.Type
          , buildFlags : BuildFlags.Type
          , arch : Arch.Type
          , suffix : Text
          }
      , default =
          { codename = Docker.Trixie
          , prefix = "MinaArtifact"
          , network = Network.Type.Devnet
          , profile = Profiles.Type.Devnet
          , artifact = Artifacts.Type.Daemon
          , buildFlags = BuildFlags.Type.None
          , suffix = "docker-image"
          , arch = Arch.Type.Amd64
          }
      }

let dependsOn =
          \(spec : DepsSpec.Type)
      ->  let network = "${Network.capitalName spec.network}"

          let profileSuffix = "${Profiles.toSuffixUppercase spec.profile}"

          let key = "${Artifacts.lowerName spec.artifact}-${spec.suffix}"

          let buildFlagSuffix =
                merge
                  { None = ""
                  , Instrumented =
                      "${BuildFlags.toSuffixUppercase spec.buildFlags}"
                  }
                  spec.buildFlags

          let archSuffix = merge { Amd64 = "", Arm64 = "Arm64" } spec.arch

          in  [ { name =
                    "${spec.prefix}${capitalName
                                       spec.codename}${network}${profileSuffix}${buildFlagSuffix}${archSuffix}"
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
            , Trixie = Docker.Trixie
            , Questing = Docker.Questing
            }
            debian

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , ofDebian = ofDebian
    , dependsOn = dependsOn
    , DepsSpec = DepsSpec
    }
