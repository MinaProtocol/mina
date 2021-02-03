let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let OpamInit = ../Command/OpamInit.dhall

let Cmd = ../Lib/Cmds.dhall

let deployEnv = "DOCKER_DEPLOY_ENV"

in

{
  build = \(duneProfile : Text) ->
    Command.build
      Command.Config::{
        commands =
            -- Build test executive binary
            OpamInit.andThenRunInDocker [
              "DUNE_PROFILE=${duneProfile}",
              -- add zexe standardization preprocessing step (see: https://github.com/CodaProtocol/coda/pull/5777)
              "PREPROCESSOR=./scripts/zexe-standardize.sh"
            ] "./buildkite/scripts/build-test-executive.sh"
            
            #
            
            [
              -- Cache test-executive binary
              Cmd.run "artifact-cache-helper.sh test_executive.exe --upload"
            ],
        label = "Build test-executive | dune profile: ${duneProfile}",
        key = "build-test-executive",
        target = Size.XLarge
      },

  execute = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            [
              -- Download test dependencies
              Cmd.run "artifact-cache-helper.sh test_executive.exe",
              Cmd.run "artifact-cache-helper.sh ${deployEnv}",

              -- Execute test based on BUILD image
              Cmd.run (
                "source ${deployEnv} && ./test_executive.exe cloud" ++
                " --coda-image gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH" ++
                " --coda-automation-location ./automation" ++
                " ${testName}"
              )
            ],
        label = "Execute integration test: ${testName}",
        key = "integration-test-${testName}",
        target = Size.Medium,
        depends_on = dependsOn
      }
}
