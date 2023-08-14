open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Test_common.Make (Inputs)

  let num_extra_keys = 1000

  let test_name = "mock"

  let config =
    let open Test_config in
    { default with
      genesis_ledger =
        [ { Test_Account.account_name = "receiver-key"
          ; balance = "9999999"
          ; timing = Untimed
          }
        ; { account_name = "empty-bp-key"; balance = "0"; timing = Untimed }
        ; { account_name = "snark-node-key"; balance = "0"; timing = Untimed }
        ]
        @ List.init num_extra_keys ~f:(fun i ->
              let i_str = Int.to_string i in
              { Test_Account.account_name =
                  String.concat [ "sender-account"; i_str ]
              ; balance = "10000"
              ; timing = Untimed
              } )
    ; block_producers =
        [ { node_name = "receiver"; account_name = "receiver-key" }
        ; { node_name = "empty_node-1"; account_name = "empty-bp-key" }
        ; { node_name = "empty_node-2"; account_name = "empty-bp-key" }
        ; { node_name = "empty_node-3"; account_name = "empty-bp-key" }
        ; { node_name = "empty_node-4"; account_name = "empty-bp-key" }
        ; { node_name = "observer"; account_name = "empty-bp-key" }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
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
    }

  let run _network _t = Malleable_error.return ()
end
