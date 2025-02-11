let B = ../External/Buildkite.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunInToolchain = ./RunInToolchain.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  \(mina_suffix : Text)
        ->  \(testnet : Text)
        ->  \(wait_between_graphql_poll : Text)
        ->  \(wait_before_final_check : Text)
        ->  \(soft_fail : B/SoftFail)
        ->  Command.build
              Command.Config::{
              , commands =
                  RunInToolchain.runInToolchainBullseye
                    ([] : List Text)
                    "./buildkite/scripts/connect/connect-to-network.sh ${mina_suffix} ${testnet} ${wait_between_graphql_poll} ${wait_before_final_check} "
              , label = "Connect to ${testnet}"
              , soft_fail = Some soft_fail
              , key = "connect-to-${testnet}"
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
