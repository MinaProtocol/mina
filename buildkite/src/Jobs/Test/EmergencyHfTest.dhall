let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall


let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall


let ReplayerTest = ../../Command/ReplayerTest.dhall
let Profiles = ../../Constants/Profiles.dhall
let Dockers = ../../Constants/DockerVersions.dhall

let Cmd = ../../Lib/Cmds.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "scripts/archive/emergency_hf")
          , S.strictlyStart (S.contains "src/app/archive")
          ]
        , path = "Test"
        , name = "EmergencyHfTest"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
        }
      , steps = [ 
        Command.build
          Command.Config::{
            commands = [
              Cmd.run "PSQL=\"docker exec replayer-postgres psql\" ./scripts/archive/emergency_hf/test/runner.sh "
            ],
            label = "Emergency HF test",
            key = "emergency-hf-test",
            target = Size.Large
          }
       ]
      }
