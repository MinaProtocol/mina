let Profiles = ./Profiles.dhall

let Artifacts = ./Artifacts.dhall

let Network = ./Network.dhall

let DebianVersions = ./DebianVersions.dhall

let BuildFlags = ./BuildFlags.dhall

let Docker
    : Type
    = < Bookworm | Bullseye | Jammy | Focal | Noble >

let capitalName =
      \(docker : Docker) ->
        merge
          { Bookworm = "Bookworm"
          , Bullseye = "Bullseye"
          , Jammy = "Jammy"
          , Focal = "Focal"
          , Noble = "Noble"
          }
          docker

let lowerName =
      \(docker : Docker) ->
        merge
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
          , artifact : Artifacts.Type
          , buildFlags : BuildFlags.Type
          , suffix : Text
          }
      , default =
        { codename = Docker.Bullseye
        , prefix = "MinaArtifact"
        , network = Network.Type.Berkeley
        , profile = Profiles.Type.Devnet
        , artifact = Artifacts.Type.Daemon
        , buildFlags = BuildFlags.Type.None
        , suffix = "docker-image"
        }
      }

let dependsOn =
      \(spec : DepsSpec.Type) ->
        let network = "${Network.capitalName spec.network}"

        let profileSuffix = "${Profiles.toSuffixUppercase spec.profile}"

        let key = "${Artifacts.lowerName spec.artifact}-${spec.suffix}"

        let buildFlagSuffix =
              merge
                { None = ""
                , Instrumented =
                    "${BuildFlags.toSuffixUppercase spec.buildFlags}"
                }
                spec.buildFlags

        in  [ { name =
                  "${spec.prefix}${capitalName
                                     spec.codename}${network}${profileSuffix}${buildFlagSuffix}"
              , key
              }
            ]

let ofDebian =
      \(debian : DebianVersions.DebVersion) ->
        merge
          { Bookworm = Docker.Bookworm
          , Bullseye = Docker.Bullseye
          , Jammy = Docker.Jammy
          , Focal = Docker.Focal
          , Noble = Docker.Noble
          }
          debian

in  { Type = Docker, capitalName, lowerName, ofDebian, dependsOn, DepsSpec }
