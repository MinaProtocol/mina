open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Test_common.Make (Inputs)

  let num_extra_keys = 1000

  let test_name = "mock"

  let config =
    let open Test_config in
    let open Node_config in
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
        [ bp "receiver" ()
        ; bp "empty_node-1" ~account_name:"empty-bp-key" ()
        ; bp "empty_node-2" ~account_name:"empty-bp-key" ()
        ; bp "observer" ~account_name:"empty-bp-key" ()
        ]
    ; snark_coordinator = snark "snark-node" 4
    ; txpool_max_size = 10_000_000
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    ; seed_nodes = [ seed "seed-0" (); seed "seed-1" () ]
    ; archive_nodes = [ archive "archive-node" () ]
    }

  let run _network _t = Malleable_error.return ()
end
