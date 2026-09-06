let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Docker = ../../Constants/Docker/Package.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let S = ../../Lib/SelectFiles.dhall

let DockerImage = ../../Command/DockerImage.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "dockerfiles/toolchain/1-")
          , S.strictlyStart (S.contains "dockerfiles/toolchain/2-")
          , S.strictlyStart (S.contains "dockerfiles/toolchain/3-")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Release/MinaToolchainArtifact")
          , S.strictly (S.contains "opam.export")
          , S.strictlyEnd (S.contains "rust-toolchain.toml")
          ]
        , path = "Release"
        , name = "MinaToolchainArtifactJammy"
        , tags = [ PipelineTag.Type.Toolchain ]
        }
      , steps =
        [ let toolchainBullseyeSpec =
                DockerImage.ReleaseSpec::{
                , service = Docker.Type.Toolchain
                , deb_codename = DebianVersions.DebVersion.Jammy
                , no_cache = True
                , deb_install_mode = DockerImage.DebianInstallMode.NoInstall
                , docker_repo = DockerRepo.Type.Public
                , save_to_ci_cache = True
                , size = Size.XLarge
                }

          in  DockerImage.generateStep toolchainBullseyeSpec
        ]
      }
