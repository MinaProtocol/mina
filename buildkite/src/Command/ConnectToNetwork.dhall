let B = ../External/Buildkite.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let RunInToolchain = ./RunInToolchain.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Spec =
      { Type =
          { dependsOn : List Command.TaggedKey.Type
          , mina_suffix : Text
          , mina_profile : Text
          , testnet : Text
          , wait_between_graphql_poll : Text
          , stall_timeout : Text
          , hard_timeout : Text
          , soft_fail : B/SoftFail
          , peer_list_url : Text
          }
      , default =
          { wait_between_graphql_poll = "40s"
          , stall_timeout = "8min"
          , hard_timeout = "60min"
          , soft_fail = B/SoftFail.Boolean False
          }
      }

in  { Spec = Spec
    , step =
            \(spec : Spec.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                  RunInToolchain.runInDefaultToolchain
                    DebianVersions.overrideEnvs
                    "./buildkite/scripts/connect/connect-to-network.sh --mina-debian-network ${spec.mina_suffix} --mina-profile ${spec.mina_profile} --network-name ${spec.testnet} --wait-between-polling ${spec.wait_between_graphql_poll} --stall-timeout ${spec.stall_timeout} --hard-timeout ${spec.hard_timeout} --peer-list-url ${spec.peer_list_url}"
              , label = "Connect to ${spec.testnet}"
              , soft_fail = Some spec.soft_fail
              , key = "connect-to-${spec.testnet}"
              , target = Size.Generic
              , depends_on = spec.dependsOn
              }
    }
