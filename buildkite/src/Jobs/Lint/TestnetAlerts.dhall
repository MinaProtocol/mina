let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "automation/terraform/monitoring/o1-testnet-alerts" "tf"
          , S.strictlyStart
              (S.contains "automation/terraform/modules/testnet-alerts")
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/TestnetAlerts")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Release/TestnetAlerts")
          ]
        , path = "Lint"
        , name = "TestnetAlerts"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Lint
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "cd automation/terraform/monitoring && terraform init && terraform destroy -auto-approve"
              , Cmd.run
                  (     "terraform apply -auto-approve -target module.o1testnet_alerts.null_resource.alert_rules_lint"
                    ++  " -target module.o1testnet_alerts.null_resource.alert_rules_check"
                  )
              ]
            , label = "Lint Testnet alert rules"
            , key = "lint-testnet-alerts"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
