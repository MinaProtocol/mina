let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let deployEnv = "DOCKER_DEPLOY_ENV"

in

{ step = \(testName : Text) -> \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands = [
            Cmd.run (
              "if [ ! -f ${deployEnv} ]; then " ++
                "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs ${deployEnv} .; " ++
              "fi"
            ),

            -- Build test executive binary and cache
            -- TODO: cache using `cacheThrough` method (see: https://github.com/MinaProtocol/mina/blob/develop/buildkite/src/Jobs/Lint/ValidationService.dhall#L25)
            Cmd.run "chmod -R 777 src/app/test_executive",
            Cmd.runInDocker
              Cmd.Docker::{
                image = (../Constants/ContainerImages.dhall).codaToolchain,
                extraEnv = [ "DUNE_PROFILE=testnet_postake_medium_curves" ]
              }
              "dune build --verbose --profile=\\\${DUNE_PROFILE} src/app/test_executive/test_executive.exe",
            Cmd.run "cp src/app/test_executive/test_executive.exe . && buildkite/scripts/buildkite-artifact-helper.sh test_executive.exe",

            -- Execute test based on BUILD image
            Cmd.run ( 
              "source ${deployEnv} && test_executive.exe cloud" ++
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
