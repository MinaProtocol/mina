let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall
let Command = ../Command/Base.dhall
let OpamInit = ../Command/Base.dhall
let Docker = ../Command/Docker/Type.dhall
let Size =  ../Command/Size.dhall
let Cmd = ../Lib/Cmds.dhall
let S  = ../Lib/SelectFiles.dhall
let DockerArtifact = ../Command/DockerArtifact.dhall
let OpamInit = ../Command/OpamInit.dhall
in
let name = "BlockProductionTest"
let uploadDeployEnv =
  Command.build
    Command.Config::
      { commands = [ Cmd.run "bash buildkite/script/export-docker-env.sh" ]
      , label = "Upload DOCKER_DEPLOY_ENV for coda-daemon container"
      , key = "artifact-upload"
      , target = Size.Small
      }
let buildTestExecutive =
  Command.build
    Command.Config::
      { commands = OpamInit.andThenRunInDocker ([] : List Text) "dune build --profile=testnet_postake_medium_curves src/app/test_executive/test_executive.exe"
      , label = "Build and run test-executive"
      , key = "build-test-executive"
      , target = Size.Large
      , docker = None Docker.Type
      , depends_on = [ { name = name, key = "docker-artifact" } ]
      }
in
Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/BlockProductionTest")
          , S.strictlyStart (S.contains "buildkite/script/export-docker-env.sh")
          , S.strictlyStart (S.contains "src/lib") ]
        , name = "Block Production Test"
        }
    , steps =
      [ uploadDeployEnv
      , DockerArtifact.generateStep [ {name = name, key = "artifact-upload"} ]
      , buildTestExecutive
      ]
    }