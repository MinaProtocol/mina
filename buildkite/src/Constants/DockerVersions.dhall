let Profiles = ./Profiles.dhall

let Artifacts = ./Artifacts.dhall

let Network = ./Network.dhall

let Docker
    : Type
    = < Bookworm | Bullseye | Jammy | Focal >

let capitalName =
          \(docker : Docker)
      ->  merge
            { Bookworm = "Bookworm"
            , Bullseye = "Bullseye"
            , Jammy = "Jammy"
            , Focal = "Focal"
            }
            docker

let lowerName =
          \(docker : Docker)
      ->  merge
            { Bookworm = "bookworm"
            , Bullseye = "bullseye"
            , Jammy = "jammy"
            , Focal = "focal"
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

let dependsOn =
          \(docker : Docker)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(binary : Artifacts.Type)
      ->  dependsOnStep docker "MinaArtifact" network profile binary

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    , dependsOnStep = dependsOnStep
    }
