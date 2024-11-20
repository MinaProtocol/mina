let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

in  { executeLocal =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-local.sh ${testName}"
                ]
              , artifact_paths =
                [ SelectFiles.exactly "." "${testName}.local.test.log" ]
              , label = "${testName} integration test local"
              , key = "integration-test-${testName}-local"
              , target = Size.Integration
              , depends_on = dependsOn
              }
    }
