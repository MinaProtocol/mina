let MinaArtifactToolchain = ../../Command/MinaArtifactToolchain.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Size = ../../Command/Size.dhall

in  MinaArtifactToolchain.pipeline
      DockerImage.ReleaseSpec::{
      , service = Artifacts.Type.Toolchain
      , deb_codename = DebianVersions.DebVersion.Questing
      , no_cache = True
      , deb_install_mode = DockerImage.DebianInstallMode.NoInstall
      , size = Size.XLarge
      }
