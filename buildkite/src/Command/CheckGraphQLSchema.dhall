let Command = ./Base.dhall

let RunInToolchain = ./RunInToolchain.dhall

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                  RunInToolchain.runInToolchainBullseye
                    ([] : List Text)
                    "./buildkite/scripts/check-graphql-schema.sh"
              , label = "Check GraphQL Schema"
              , key = "check-graphql-schema"
              , depends_on = dependsOn
              }
    }
