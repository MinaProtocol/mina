let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let WithCargo = ../../Command/WithCargo.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
in

let image_age = "60"
let dryrun = "true"

in 

Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "automation/services")
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Maintenance/RemoveOldSinks")
          ]
        , path = "Maintenance"
        , name = "RemoveOldSinks"
        , tags = [ PipelineTag.Type.Maintenance ]
        }
    , steps = [
      Command.build
        Command.Config::{
          commands = RunInToolchain.runInToolchain ([] : List Text) "automation/services/gcloud-cleaner/scripts/clean_old_sinks.sh  --age='${image_age}' --dryrun='${dryrun}'"
          , label = "Maintenance: Clean old sinks"
          , key = "maintenance-clean-old-sinks"
          , target = Size.Small
          , docker = None Docker.Type
        }
    ]
    }
