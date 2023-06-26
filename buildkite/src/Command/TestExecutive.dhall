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
              Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh ${testName} && ./buildkite/scripts/upload-test-results.sh ${testName} "
            ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.test.log"],
        label = "${testName} integration test",
        key = "integration-test-${testName}",
        target = Size.Integration,
        depends_on = dependsOn
      },

  buildJs = \(duneProfile : Text) -> 
    Command.build
      Command.Config::{
        commands =
            -- Build js test archive
            RunInToolchain.runInToolchainBuster ([] : List Text) "./buildkite/scripts/build-js-tests.sh"
            
            #

            [
              -- Cache js test archive
              Cmd.run "artifact-cache-helper.sh snarkyjs_test.tar.gz --upload"
            ],
        label = "Build JS integration tests",
        key = "build-js-tests",
        target = Size.XLarge
      },

  executeWithJs = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            [
              Cmd.run "artifact-cache-helper.sh snarkyjs_test.tar.gz && tar -xzf snarkyjs_test.tar.gz",

              -- Execute test based on BUILD image
              Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh ${testName}",
                          
              -- Upload test report
              Cmd.run "./buildkite/scripts/upload-test-results.sh ${testName}"
            ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.test.log"],
        label = "${testName} integration test",
        key = "integration-test-${testName}",
        target = Size.Integration,
        depends_on = dependsOn,
        soft_fail = Some (B/SoftFail.Boolean True)
      }
}
