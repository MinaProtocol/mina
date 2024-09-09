let Prelude = ../External/Prelude.dhall

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

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

let dependsOn =
          \(docker : Docker)
      ->  \(network : Optional Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(binary : Artifacts.Type)
      ->  let profileSuffix = Profiles.toSuffixUppercase profile

          let prefix = "MinaArtifact"

          let suffix = "docker-image"

          let maybeNetwork =
                Optional/map
                  Network.Type
                  Text
                  (\(network : Network.Type) -> "-${Network.lowerName network}")
                  network

          let networkOrDefault = Optional/default Text "" maybeNetwork

          let key =
                "${Artifacts.lowerName
                     binary}${networkOrDefault}-${lowerName docker}-${suffix}"

          in  merge
                { Bookworm =
                  [ { name = "${prefix}${capitalName docker}${profileSuffix}"
                    , key = key
                    }
                  ]
                , Bullseye =
                  [ { name = "${prefix}${capitalName docker}${profileSuffix}"
                    , key = key
                    }
                  ]
                , Jammy =
                  [ { name = "${prefix}${capitalName docker}${profileSuffix}"
                    , key = key
                    }
                  ]
                , Focal =
                  [ { name = "${prefix}${capitalName docker}${profileSuffix}"
                    , key = key
                    }
                  ]
                }
                docker

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    }
