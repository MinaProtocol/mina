let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Command = ../../Command/Base.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
in
let name = "BlockProductionTest"
let runTestExecutive =
  Command.build
    Command.Config::
      { commands = OpamInit.andThenRunInDocker
          ([ "BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON"
           , "AWS_ACCESS_KEY_ID"
           , "AWS_SECRET_ACCESS_KEY"
           , "AWS_REGION"
           , "BUILDKITE_BRANCH"
           ]) "bash buildkite/scripts/run-test.sh"
      , label = "Build and run test-executive"
      , key = "run-test-executive"
      , target = Size.Large
      , docker = None Docker.Type
      , depends_on = [ { name = "Artifact", key = "docker-artifact" } ]
      }
in
Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/Test/BlockProductionTest")
          , S.strictlyStart (S.contains "buildkite/scripts/run-test.sh")
          , S.strictlyStart (S.contains "src/lib") ]
        , path = "Test"
        , name = name
        }
    , steps = [ runTestExecutive ]
    }