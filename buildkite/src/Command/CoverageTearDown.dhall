let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall
let RunInToolchain = ./RunInToolchain.dhall in

{ execute = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
          RunInToolchain.runInToolchainBullseye ["COVERALLS_TOKEN"]
            "buildkite/scripts/finish-coverage-data-upload.sh",
        label = "Finish coverage data gathering",
        key = "finish-coverage-data",
        target = Size.Small,
        depends_on = dependsOn
      }
}
