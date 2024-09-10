let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

in  { executeCloud =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-cloud.sh ${testName}"
                ]
              , artifact_paths =
                [ SelectFiles.exactly "." "${testName}.cloud.test.log" ]
              , label = "${testName} integration test"
              , key = "integration-test-${testName}"
              , depends_on = dependsOn
              }
    , executeLocal =
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
              , depends_on = dependsOn
              }
    }
