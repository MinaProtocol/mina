let MinaArtifactToolchain = ../../Command/MinaArtifactToolchain.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

in  MinaArtifactToolchain.pipeline
      DockerImage.ReleaseSpec::{
      , service = Artifacts.Type.Toolchain
      , deb_codename = DebianVersions.DebVersion.Focal
      , no_cache = True
      , no_debian = True
      }
