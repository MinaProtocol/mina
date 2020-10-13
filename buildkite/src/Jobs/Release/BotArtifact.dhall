let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerArtifact = ../../Command/DockerArtifact.dhall

let dependsOn = [ { name = "BotArtifact", key = "bot-artifacts-build" } ]

let spec = DockerArtifact.ReleaseSpec::{
    deps=dependsOn,
    service="bot",
    commit="\\\${BUILDKITE_COMMIT}",
    deploy_env_file="BOT_DEPLOY_ENV",
    extra_args="",
    step_key="bot-docker-artifact"
}

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/BotArtifact"),
          S.strictlyStart (S.contains "frontend/bot")
        ],
        path = "Release",
        name = "BotArtifact"
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
              Cmd.run "echo export CODA_VERSION=$(cat frontend/bot/package.json | jq '.version') > BOT_DEPLOY_ENV && buildkite/scripts/buildkite-artifact-helper.sh BOT_DEPLOY_ENV"
          ],
          label = "Build Mina testnet bot artifacts",
          key = "bot-artifacts-build",
          target = Size.Small,
          artifact_paths = [ S.contains "frontend/bot/*.json" ]
        },
      DockerArtifact.generateStep spec
    ]
  }
