open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs.Engine

  open Test_common.Make (Inputs)

  let num_extra_keys = 1000

  let test_name = "mock"

  let config =
    let open Test_config in
    { default with
      genesis_ledger =
        [ test_account "receiver-key" "9999999"
        ; test_account "empty-bp-key" "0"
        ; test_account "snark-node-key" "0"
        ]
        @ List.init num_extra_keys ~f:(fun i ->
              let i_str = Int.to_string i in
              test_account ("sender-account-" ^ i_str) "10000" )
    ; block_producers =
        [ bp "receiver" "another-docker-image"
        ; bp "empty_node-1" ~account_name:"empty-bp-key" !Network.mina_image
        ; bp "empty_node-2" ~account_name:"empty-bp-key" !Network.mina_image
        ; bp "empty_node-3" ~account_name:"empty-bp-key" !Network.mina_image
        ; bp "empty_node-4" ~account_name:"empty-bp-key" !Network.mina_image
        ; bp "observer" ~account_name:"empty-bp-key" !Network.mina_image
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; docker_image = !Network.mina_image
          ; worker_nodes = 4
          }
    ; txpool_max_size = 10_000_000
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    ; seed_nodes =
        [ { node_name = "seed-0"
          ; account_name = "seed-0-key"
          ; docker_image = "seed-docker-image"
          }
        ]
    ; snark_workers =
        [ { node_name = "snark-0"
          ; account_name = "snark-0-key"
          ; docker_image = "snark-docker-image"
          }
        ]
    ; archive_nodes =
        [ { node_name = "archive-0"
          ; account_name = "archive-0-key"
          ; docker_image = "archive-docker-image"
          }
        ]
    }

  let run _network _t = Malleable_error.return ()
end
