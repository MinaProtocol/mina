let Profiles = ./Profiles.dhall

let Artifacts = ./Artifacts.dhall

let Network = ./Network.dhall

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
          , artifact : Artifacts.Type
          , suffix : Text
          }
      , default =
          { codename = Docker.Bullseye
          , prefix = "MinaArtifact"
          , network = Network.Type.Berkeley
          , profile = Profiles.Type.Standard
          , artifact = Artifacts.Type.Daemon
          , suffix = "docker-image"
          }
      }

let dependsOn =
          \(spec : DepsSpec.Type)
      ->  let network = "${Network.capitalName spec.network}"

          let profileSuffix = "${Profiles.toSuffixUppercase spec.profile}"

          let key = "${Artifacts.lowerName spec.artifact}-${spec.suffix}"

          in  [ { name =
                    "${spec.prefix}${capitalName
                                       spec.codename}${network}${profileSuffix}"
                , key = key
                }
              ]

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    , DepsSpec = DepsSpec
    }
