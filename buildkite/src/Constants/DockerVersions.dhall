let Prelude = ../External/Prelude.dhall
let Profiles = ./Profiles.dhall

let Docker: Type  = < Bookworm | Bullseye | Buster | Jammy | Focal >

let capitalName = \(docker : Docker) ->
  merge {
    Bookworm = "Bookworm"
    , Bullseye = "Bullseye"
    , Buster = "Buster"
    , Jammy = "Jammy"
    , Focal = "Focal"
  } docker

let lowerName = \(docker : Docker) ->
  merge {
    Bookworm = "bookworm"
    , Bullseye = "bullseye"
    , Buster = "buster"
    , Jammy = "jammy"
    , Focal = "focal"
  } docker

let dependsOn = \(docker : Docker) -> \(profile : Profiles.Type) -> \(binary: Text) -> 
  let profileSuffix = Profiles.toSuffixUppercase profile in
  let prefix = "MinaArtifact" in 
  let suffix = "docker-image" in
  merge {
    Bookworm = [{ name = "${prefix}${profileSuffix}", key = "${binary}-${lowerName docker}-${suffix}" }]
    , Bullseye = [{ name = "${prefix}${capitalName docker}${profileSuffix}", key = "${binary}-${lowerName docker}-${suffix}" }]
    , Buster = [{ name = "${prefix}${capitalName docker}${profileSuffix}", key = "${binary}-${lowerName docker}-${suffix}" }]
    , Jammy = [{ name = "${prefix}${capitalName docker}${profileSuffix}", key = "${binary}-${lowerName docker}-${suffix}" }]
    , Focal = [{ name = "${prefix}${capitalName docker}${profileSuffix}", key = "${binary}-${lowerName docker}-${suffix}" }]
  } docker

in

{
  Type = Docker
  , capitalName = capitalName
  , lowerName = lowerName
  , dependsOn = dependsOn
}