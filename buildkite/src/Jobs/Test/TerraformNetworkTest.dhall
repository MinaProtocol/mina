let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let buildTestCmd
    : Size -> Command.Type
    =     \(cmd_target : Size)
      ->  Command.build
            Command.Config::{
            , commands = [ Cmd.run "buildkite/scripts/terraform-test.sh" ]
            , label = "Terraform: Test"
            , key = "terraform-network-test"
            , target = cmd_target
            , docker = None Docker.Type
            , soft_fail = Some (B/SoftFail.Boolean True)
            }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let unitDirtyWhen =
                [ S.strictlyStart (S.contains "automation/terraform")
                , S.strictlyStart (S.contains "helm")
                , S.strictlyStart
                    (S.contains "buildkite/src/Jobs/Test/TerraformNetworkTest")
                , S.strictlyStart
                    (S.contains "buildkite/scripts/terraform-test.sh")
                ]

          in  JobSpec::{
              , dirtyWhen = unitDirtyWhen
              , path = "Test"
              , name = "TerraformNetworkTest"
              , tags =
                [ PipelineTag.Type.Fast
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              }
      , steps = [ buildTestCmd Size.Large ]
      }
