let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

in  { executeLocalApps =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-local-apps.sh ${testName}"
                ]
              , artifact_paths =
                [ SelectFiles.contains "${testName}*.local.test.log" ]
              , label = "${testName} integration test local-apps"
              , key = "integration-test-${testName}-local-apps"
              , target = Size.Integration
              , depends_on = dependsOn
              }
    }
