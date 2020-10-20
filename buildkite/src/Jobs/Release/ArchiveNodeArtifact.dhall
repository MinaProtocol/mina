let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall

let dependsOn = [ { name = "ArchiveNodeArtifact", key = "build-archive-deb-pkg" } ]

let spec = DockerImage.ReleaseSpec::{
    deps=dependsOn,
    deploy_env_file="ARCHIVE_DOCKER_DEPLOY",
    step_key="archive-docker-image"
}

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/ArchiveNodeArtifact"),
          S.strictlyStart (S.contains "scripts/archive")
        ],
        path = "Release",
        name = "ArchiveNodeArtifact"
      },
    steps = [
      Command.build
        Command.Config::{
          commands = OpamInit.andThenRunInDocker [
            "DUNE_PROFILE=testnet_postake_medium_curves",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "BUILDKITE"
          ] "./buildkite/scripts/ci-archive-release.sh" # [ Cmd.run "buildkite/scripts/buildkite-artifact-helper.sh ./${spec.deploy_env_file}" ],
          label = "Build Mina's archive-node debian package",
          key = "build-archive-deb-pkg",
          target = Size.XLarge,
          artifact_paths = [ S.contains "./*.deb" ]
        },
      DockerImage.generateStep spec
    ]
  }
