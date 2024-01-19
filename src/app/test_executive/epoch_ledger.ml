open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let fork_config : Runtime_config.Fork_config.t =
    { previous_state_hash =
        "3NKSiqFZQmAS12U8qeX4KNo8b4199spwNh7mrSs4Ci1Vacpfix2Q"
    ; previous_length = 300000
    ; previous_global_slot = 500000
    }


  let config =
    let open Test_config in 
    let staking_accounts : Test_Account.t list =
      [ { account_name = "node-a-key"; balance = "0"; timing = Untimed }
      ; { account_name = "node-b-key"; balance = "0"; timing = Untimed }
      ]
    in
    let staking : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 42)
      in
      let epoch_ledger = staking_accounts in
      { epoch_ledger; epoch_seed }
    in
    (* next accounts contains staking accounts, with balances changed, one new account *)
    let next_accounts : Test_Account.t list =
      [ { account_name = "node-a-key"; balance = "0"; timing = Untimed }
      ; { account_name = "node-b-key"; balance = "0"; timing = Untimed }
      ]
    in
    let next : Test_config.Epoch_data.Data.t =
      let epoch_seed =
        Epoch_seed.to_base58_check Snark_params.Tick.Field.(of_int 1729)
      in
      let epoch_ledger = next_accounts in
      { epoch_ledger; epoch_seed }
    in
    { default with 
      requires_graphql = true 
    ; epoch_data = Some { staking; next = Some next }
    ; genesis_ledger = next_accounts
    ; block_producers =
    [ { node_name = "node-a"; account_name = "node-a-key" }
    ; { node_name = "node-b"; account_name = "node-b-key" }
    ]
    ; proof_config =
      { proof_config_default with 
      fork = Some fork_config }    
      }      

  let run network t =
    let open Malleable_error.Let_syntax in 
    let all_mina_nodes = Network.all_mina_nodes network in 
    let%bind () =
      wait_for t 
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_mina_nodes))
  in 
    section "wait for 3 block to be produced"
      (wait_for t (Wait_condition.blocks_to_be_produced 3))
end
