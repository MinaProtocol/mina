let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

in  { executeCloud =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  let key = "integration-test-${testName}-cloud"

            in  Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.run
                        "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-cloud.sh ${testName}"
                    , Cmd.run
                        "buildkite/scripts/upload-partial-coverage-data.sh ${key} dev"
                    ]
                  , artifact_paths =
                    [ SelectFiles.exactly "." "${testName}.cloud.test.log" ]
                  , label = "${testName} integration test"
                  , key = key
                  , target = Size.Integration
                  , depends_on = dependsOn
                  }
    , executeLocal =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  let key = "integration-test-${testName}-local"

            in  Command.build
                  Command.Config::{
                  , commands =
                    [ Cmd.run
                        "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-local.sh ${testName}"
                    , Cmd.run
                        "buildkite/scripts/upload-partial-coverage-data.sh ${key} dev"
                    ]
                  , artifact_paths =
                    [ SelectFiles.exactly "." "${testName}.local.test.log" ]
                  , label = "${testName} integration test local"
                  , key = key
                  , target = Size.Integration
                  , depends_on = dependsOn
                  }
    }
