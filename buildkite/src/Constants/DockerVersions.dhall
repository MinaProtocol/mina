let Profiles = ./Profiles.dhall

let Artifacts = ./Artifacts.dhall

let Network = ./Network.dhall

let BuildFlags = ./BuildFlags.dhall

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
      ->  \(buildFlag : BuildFlags.Type)
      ->  \(binary : Artifacts.Type)
      ->  let network = "${Network.capitalName network}"

          let buildFlag = "${BuildFlags.toSuffixUppercase buildFlag}"

          let profileSuffix = "${Profiles.toSuffixUppercase profile}"

          let suffix = "docker-image"

          let key = "${Artifacts.lowerName binary}-${suffix}"

          in  merge
                { Bookworm =
                  [ { name =
                        "${prefix}${capitalName
                                      docker}${network}${profileSuffix}${buildFlag}"
                    , key = key
                    }
                  ]
                , Bullseye =
                  [ { name =
                        "${prefix}${capitalName
                                      docker}${network}${profileSuffix}${buildFlag}"
                    , key = key
                    }
                  ]
                , Jammy =
                  [ { name =
                        "${prefix}${capitalName
                                      docker}${network}${capitalName
                                                           docker}${profileSuffix}${buildFlag}"
                    , key = key
                    }
                  ]
                , Focal =
                  [ { name =
                        "${prefix}${capitalName
                                      docker}${network}${capitalName
                                                           docker}${profileSuffix}${buildFlag}"
                    , key = key
                    }
                  ]
                }
                docker

let dependsOn =
          \(docker : Docker)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  \(binary : Artifacts.Type)
      ->  dependsOnStep
            docker
            "MinaArtifact"
            network
            profile
            BuildFlags.Type.None
            binary

in  { Type = Docker
    , capitalName = capitalName
    , lowerName = lowerName
    , dependsOn = dependsOn
    , dependsOnStep = dependsOnStep
    }
