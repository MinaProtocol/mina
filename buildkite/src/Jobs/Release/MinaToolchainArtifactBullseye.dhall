let MinaArtifactToolchain = ../../Command/MinaArtifactToolchain.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let Size = ../../Command/Size.dhall

in  MinaArtifactToolchain.pipeline
      DockerImage.ReleaseSpec::{
      , service = Artifacts.Type.Toolchain
      , deb_codename = DebianVersions.DebVersion.Bullseye
      , no_cache = True
      , deb_install_mode = DockerImage.DebianInstallMode.NoInstall
      , docker_repo = DockerRepo.Type.Public
      , save_to_ci_cache = True
      , size = Size.XLarge
      }
