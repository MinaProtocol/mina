let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall
let Command = ../Command/Base.dhall
let OpamInit = ../Command/Base.dhall
let Docker = ../Command/Docker/Type.dhall
let Size =  ../Command/Size.dhall
let Cmd = ../Lib/Cmds.dhall
let S  = ../Lib/SelectFiles.dhall
in 

Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/BlockProductionTest")
          , S.strictlyStart (S.contains "src/lib") ]
        , name = "Block Production Test"
        }
    , steps =
      [ Command.build Command.Config::
          { commands = [ Cmd.run "bash buildkite/script/export-docker-env.sh"
                       , Cmd.run "echo $CODA_VERSION" ]
          , label = "Block Production Test"
          , key = "test"
          , target = Size.Large
          , docker = Some Docker::
            { image = (../Constants/ContainerImages.dhall).codaToolchain }
          }
      ]
    }