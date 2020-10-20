let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall

let dependsOn = [ { name = "BotArtifact", key = "setup-deploy-env" } ]

let spec = DockerImage.ReleaseSpec::{
    deps=dependsOn,
    service="bot",
    commit="\\\${BUILDKITE_COMMIT}",
    deploy_env_file="BOT_DEPLOY_ENV",
    extra_args="",
    step_key="bot-docker-image"
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
          label = "Setup Mina's bot docker image deploy environment",
          key = "setup-deploy-env",
          target = Size.Small,
          artifact_paths = [ S.contains "frontend/bot/*.json" ]
        },
      DockerImage.generateStep spec
    ]
  }
