let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [
        S.exactly "automation/terraform/infrastructure/templates/testnet-alerts.yml" "tpl",
        S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/TestnetAlerts"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Release/TestnetAlerts")
      ],
      path = "Lint",
      name = "TestnetAlerts"
    },
    steps = [
      Command.build
        Command.Config::{
          commands = [
              Cmd.run "cd automation/terraform/infrastructure && terraform init",
              Cmd.run "terraform apply -auto-approve -target docker_container.lint_rules_config -target docker_container.check_rules_config" ]
          , label = "Lint Testnet alert rules"
          , key = "lint-testnet-alerts"
          , target = Size.Small
          , docker = None Docker.Type
        }
    ]
  }
