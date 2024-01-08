let Prelude = ../External/Prelude.dhall
let B = ../External/Buildkite.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let Cmd = ../Lib/Cmds.dhall
let SelectFiles = ../Lib/SelectFiles.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in

{
  executCloud = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            [
              -- Execute test based on BUILD image
              Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-cloud.sh ${testName}"
            ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.cloud.test.log"],
        label = "${testName} integration test",
        key = "integration-test-${testName}",
        target = Size.Integration,
        depends_on = dependsOn
      },

  executeLocal = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive-local.sh ${testName}"
        ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.local.test.log"],
        label = "${testName} integration test local",
        key = "integration-test-${testName}-local",
        target = Size.Integration,
        depends_on = dependsOn
      }
}
