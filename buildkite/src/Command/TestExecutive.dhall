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
  execute = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            [
              -- Execute test based on BUILD image
              Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh ${testName}"
            ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.test.log"],
        label = "${testName} integration test",
        key = "integration-test-${testName}",
        target = Size.Integration,
        depends_on = dependsOn,
        retries = [
          -- common/flake error
          Command.Retry::{ exit_status = Command.ExitStatus.Code +1, limit = Some 4 },
        ]
      }
}
