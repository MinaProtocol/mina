let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall
let RunInToolchain = ./RunInToolchain.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands =
          RunInToolchain.runInToolchainStretch ([] : List Text)
            "./buildkite/scripts/check-graphql-schema.sh",
        label = "Check GraphQL Schema",
        key = "check-graphql-schema",
        target = Size.Large,
        depends_on = dependsOn
      }
}
