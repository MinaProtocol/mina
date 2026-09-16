let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

let integrationCodename =
    -- These tests run directly on the Size.Integration agent, which is Ubuntu
    -- focal, so the .deb installed here must be the focal one. A bookworm .deb
    -- depends on libssl3, which focal does not carry, and apt then reports
    -- "mina-test-executive : Depends: libssl3 but it is not installable".
      "focal"

in  { executeLocal =
            \(testName : Text)
        ->  \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "MINA_DEB_CODENAME=${integrationCodename} ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-local.sh ${testName} ${DockerRepo.show
                                                                                                                                                                                     DockerRepo.Type.InternalEurope}"
                ]
              , artifact_paths =
                [ SelectFiles.contains "${testName}*.local.test.log" ]
              , label = "${testName} integration test local"
              , key = "integration-test-${testName}-local"
              , target = Size.Integration
              , depends_on = dependsOn
              }
    }
