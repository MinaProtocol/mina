let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerArtifact = ../../Command/DockerArtifact.dhall

let dependsOn = [ { name = "LeaderboardArtifact", key = "leaderboard-artifacts-build" } ]

let spec = DockerArtifact.ReleaseSpec::{
    deps=dependsOn,
    service="leaderboard",
    commit="\\\${BUILDKITE_COMMIT}",
    deploy_env_file="LEADERBOARD_DEPLOY_ENV",
    extra_args="",
    step_key="leaderboard-docker-artifact"
}

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/LeaderboardArtifact"),
          S.strictlyStart (S.contains "frontend/leaderboard")
        ],
        path = "Release",
        name = "LeaderboardArtifact"
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
              Cmd.run "echo export CODA_VERSION=$(cat frontend/leaderboard/package.json | jq '.version') > LEADERBOARD_DEPLOY_ENV && buildkite/scripts/buildkite-artifact-helper.sh LEADERBOARD_DEPLOY_ENV"
          ],
          label = "Build Mina testnet leaderboard artifacts",
          key = "leaderboard-artifacts-build",
          target = Size.Small,
          artifact_paths = [ S.contains "frontend/leaderboard/package.json" ]
        },
      DockerArtifact.generateStep spec
    ]
  }
