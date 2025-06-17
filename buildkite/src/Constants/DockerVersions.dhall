let Profiles = ./Profiles.dhall

let Artifacts = ./Artifacts.dhall

let Network = ./Network.dhall

let DebianVersions = ./DebianVersions.dhall

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

let dependsOnStep =
          \(docker : Docker)
      ->  \(prefix : Text)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(binary : Artifacts.Type)
      ->  let network = "${Network.capitalName network}"

          let profileSuffix = "${Profiles.toSuffixUppercase profile}"

          let suffix = "docker-image"

          let key = "${Artifacts.lowerName binary}-${suffix}"

          in  [ { name =
                    "${prefix}${capitalName docker}${network}${profileSuffix}"
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

let dependsOn =
          \(docker : Docker)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(binary : Artifacts.Type)
      ->  dependsOnStep docker "MinaArtifact" network profile binary

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , ofDebian = ofDebian
    , dependsOn = dependsOn
    , dependsOnStep = dependsOnStep
    }
