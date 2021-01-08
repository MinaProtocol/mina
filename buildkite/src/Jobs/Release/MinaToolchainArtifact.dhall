let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall

let UploadGitEnv = ../../Command/UploadGitEnv.dhall
let DockerImage = ../../Command/DockerImage.dhall
let DockerLogin = ../../Command/DockerLogin/Type.dhall


let dependsOn = [ { name = "MinaToolchainArtifact", key = "upload-git-env" } ]

let gitEnvVars = "export-git-env-vars.sh"

let commands : List Cmd.Type =
  [
      -- Setup Git environment
      Cmd.run (
        "if [ ! -f ${gitEnvVars} ]; then " ++
            "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${gitEnvVars} .; " ++
        "fi"
      ),
      -- Dockerhub: Build and release toolchain image
      Cmd.run (
        "source ${gitEnvVars} && docker build --rm --file dockerfiles/Dockerfile-toolchain --tag codaprotocol/mina-toolchain:\\\$DOCKER_TAG && " ++
          "docker push codaprotocol/mina-toolchain:\\\$DOCKER_TAG"
      ),
      -- GCR: Build and release toolchain image
      Cmd.run (
        "docker tag codaprotocol/mina-toolchain:\\\$DOCKER_TAG gcr.io/o1labs-192920/mina-toolchain:\\\$DOCKER_TAG && " ++
          "docker push gcr.io/o1labs-192920/mina-toolchain:\\\$DOCKER_TAG"
      )
  ]

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.exactly "dockerfiles/Dockerfile-toolchain" ""
        ],
        path = "Release",
        name = "MinaToolchainArtifact"
      },
    steps = [
      UploadGitEnv.step,
      Command.build
        Command.Config::{
            commands  = commands,
            label = "Build and release Mina toolchain Docker image",
            key = "mina-toolchain-image",
            target = Size.Large,
            docker_login = Some DockerLogin::{=},
            depends_on = dependsOn
        }
    ]
  }
