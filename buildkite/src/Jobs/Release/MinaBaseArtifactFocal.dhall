let MinaArtifactBase = ../../Command/MinaArtifactBase.dhall

let Docker = ../../Constants/Docker/Package.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let Size = ../../Command/Size.dhall

in  MinaArtifactBase.pipeline
      DockerImage.ReleaseSpec::{
      , service = Docker.Type.Base
      , deb_codename = DebianVersions.DebVersion.Focal
      , no_cache = True
      , deb_install_mode = DockerImage.DebianInstallMode.NoInstall
      , docker_repo = DockerRepo.Type.Public
      , save_to_ci_cache = True
      , size = Size.XLarge
      }
