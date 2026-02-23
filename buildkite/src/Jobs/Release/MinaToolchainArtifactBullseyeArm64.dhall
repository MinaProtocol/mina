let MinaArtifactToolchain = ../../Command/MinaArtifactToolchain.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Arch = ../../Constants/Arch.dhall

let Size = ../../Command/Size.dhall

in  MinaArtifactToolchain.pipeline
      DockerImage.ReleaseSpec::{
      , service = Artifacts.Type.Toolchain
      , deb_codename = DebianVersions.DebVersion.Bullseye
      , no_cache = True
      , no_debian = True
      , arch = Arch.Type.Arm64
      , size = Size.Arm64
      }
