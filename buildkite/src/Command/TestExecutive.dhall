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
  build = \(duneProfile : Text) ->
    Command.build
      Command.Config::{
        commands =
            -- Build test executive binary
            RunInToolchain.runInToolchain [
              "DUNE_PROFILE=${duneProfile}"
            ] "./buildkite/scripts/build-test-executive.sh"
            
            #
            
            [
              -- Cache test-executive binary
              Cmd.run "artifact-cache-helper.sh test_executive.exe --upload",
              Cmd.run "artifact-cache-helper.sh logproc.exe --upload"
            ],
        label = "Build test-executive",
        key = "build-test-executive",
        target = Size.XLarge,
        `if` = Some "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
      },

  execute = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            [
              -- Download test dependencies
              Cmd.run "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe",
              Cmd.run "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe",

              -- Execute test based on BUILD image
              Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh ${testName}"
            ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.test.log"],
        label = "${testName} integration test",
        key = "integration-test-${testName}",
        target = Size.Integration,
        depends_on = dependsOn,
        `if` = Some "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
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
        target = Size.Integration,
        `if` = Some "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
      },

  executeWithJs = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            [
              -- Download test dependencies
              Cmd.run "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe",
              Cmd.run "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe",
              Cmd.run "artifact-cache-helper.sh snarkyjs_test.tar.gz && tar -xzf snarkyjs_test.tar.gz",

              -- Execute test based on BUILD image
              Cmd.run "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh ${testName}"
            ],
        artifact_paths = [SelectFiles.exactly "." "${testName}.test.log"],
        label = "${testName} integration test",
        key = "integration-test-${testName}",
        target = Size.Integration,
        depends_on = dependsOn,
        `if` = Some "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'",
        soft_fail = Some (B/SoftFail.Boolean True)
      }
}
