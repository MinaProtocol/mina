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
          , testnet : Text
          , wait_between_graphql_poll : Text
          , sync_timeout : Text
          , soft_fail : B/SoftFail
          , peer_list_url : Optional Text
          }
      , default =
          { wait_between_graphql_poll = "40s"
          , sync_timeout = "25min"
          , soft_fail = B/SoftFail.Boolean False
          , peer_list_url = None Text
          }
      }

let peer_list_url_flag =
          \(peer_list_url : Optional Text)
      ->  merge
            { Some = \(url : Text) -> " --peer-list-url ${url}", None = "" }
            peer_list_url

in  { Spec = Spec
    , step =
            \(spec : Spec.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                  RunInToolchain.runInToolchain
                    DebianVersions.overrideEnvs
                    "./buildkite/scripts/connect/connect-to-network.sh --mina-debian-network ${spec.mina_suffix} --network-name ${spec.testnet} --wait-between-polling ${spec.wait_between_graphql_poll} --sync-timeout ${spec.sync_timeout}${peer_list_url_flag
                                                                                                                                                                                                                                                spec.peer_list_url}"
              , label = "Connect to ${spec.testnet}"
              , soft_fail = Some spec.soft_fail
              , key = "connect-to-${spec.testnet}"
              , target = Size.Large
              , depends_on = spec.dependsOn
              }
    }
