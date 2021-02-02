let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let OpamInit = ../Command/OpamInit.dhall

let Cmd = ../Lib/Cmds.dhall

let deployEnv = "DOCKER_DEPLOY_ENV"

in

{ step = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
            -- Build test executive binary
            OpamInit.andThenRunInDocker [
              "DUNE_PROFILE=testnet_postake_medium_curves",
              -- add zexe standardization preprocessing step (see: https://github.com/CodaProtocol/coda/pull/5777)
              "PREPROCESSOR=./scripts/zexe-standardize.sh"
            ] "./buildkite/scripts/build-test-executive.sh"
            
            #
            
            [
              -- Cache test-executive binary
              -- TODO: cache using `cacheThrough` method
              Cmd.run "buildkite/scripts/buildkite-artifact-helper.sh test_executive.exe",

              -- Download deploy env to identify test dependencies
              Cmd.run (
                "if [ ! -f ${deployEnv} ]; then " ++
                    "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${deployEnv} .; " ++
                "fi"
              ),

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
        target = Size.Large,
        depends_on = dependsOn
      }
}
