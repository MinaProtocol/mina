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
let runTestExecutive =
  Command.build
    Command.Config::
      { commands = OpamInit.andThenRunInDocker (["BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON"]) "bash buildkite/scripts/run-test.sh"
      , label = "Build and run test-executive"
      , key = "run-test-executive"
      , target = Size.Large
      , docker = None Docker.Type
      }
in
Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/BlockProductionTest")
          , S.strictlyStart (S.contains "buildkite/scripts/run-test.sh")
          , S.strictlyStart (S.contains "src/lib") ]
        , name = name
        }
    , steps = [ runTestExecutive ]
    }