let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

in  { executeDocker =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "MINA_DEB_CODENAME=bookworm ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-docker.sh ${testName} ${DockerRepo.show
                                                                                                                                                                        DockerRepo.Type.InternalEurope}"
                ]
              , artifact_paths =
                [ SelectFiles.contains "${testName}*.local.test.log" ]
              , label = "${testName} integration test docker"
              , key = "integration-test-${testName}-docker"
              , target = Size.Integration
              , depends_on = dependsOn
              }
    }
