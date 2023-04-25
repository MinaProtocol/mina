let Prelude =  ../../External/Prelude.dhall
let S = ../../Lib/SelectFiles.dhall
let Cmd =  ../../Lib/Cmds.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let WithCargo = ../../Command/WithCargo.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
in

Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/Test/HeapUsage")
          , S.strictlyStart (S.contains "src")
          ]
        , path = "Test"
        , name = "HeapUsage"
        }
    , steps =
      [ Command.build
          Command.Config::
            { commands = RunInToolchain.runInToolchain ([] : List Text) "./buildkite/scripts/heap_usage.sh"
            , label = "Heap usage"
            , key = "heap-usage"
            , target = Size.Medium
            , docker = None Docker.Type
            }
      ]
    }

