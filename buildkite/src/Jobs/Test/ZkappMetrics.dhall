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
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/Test/ZkappMetrics")
          , S.strictlyStart (S.contains "src")
          ]
        , path = "Test"
        , name = "ZkappMetrics"
        }
    , steps =
      [ Command.build
          Command.Config::
            { commands = RunInToolchain.runInToolchain ([] : List Text) "./buildkite/scripts/zkapp_metrics.sh"
            , label = "Zkapp Metrics"
            , key = "zkapp-metrics"
            , target = Size.Medium
            , docker = None Docker.Type
            }
      ]
    }

