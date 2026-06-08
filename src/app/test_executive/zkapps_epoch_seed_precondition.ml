open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let slots_per_epoch = 6

  let block_window_duration_ms = 20_000

  let staking_epoch_seed =
    Epoch_seed.of_hash Snark_params.Tick.Field.(of_int 42)

  let next_epoch_seed = Epoch_seed.of_hash Snark_params.Tick.Field.(of_int 1729)

  let config ~constants =
    let open Test_config in
    let genesis_ledger =
      let open Test_account in
      [ create ~account_name:"node-a-key" ~balance:"8000000000" ()
      ; create ~account_name:"fish1" ~balance:"3000" ()
      ]
    in
    let epoch_data =
      let mk_epoch_data epoch_seed =
        { Epoch_data.Data.epoch_ledger = genesis_ledger; epoch_seed }
      in
      let staking =
        mk_epoch_data (Epoch_seed.to_base58_check staking_epoch_seed)
      in
      let next = mk_epoch_data (Epoch_seed.to_base58_check next_epoch_seed) in
      Some { Epoch_data.staking; next = Some next }
    in
    { (default ~constants) with
      requires_graphql = true
    ; genesis_ledger
    ; epoch_data
    ; slots_per_epoch
    ; slots_per_sub_window = 1
    ; grace_period_slots = 1
    ; block_window_duration_ms
    ; proof_config =
        { proof_config_default with
          block_window_duration_ms = Some block_window_duration_ms
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" } ]
    }

  let stale_epoch_seed_precondition =
    let open Zkapp_basic.Or_ignore in
    let epoch_data seed =
      { Zkapp_precondition.Protocol_state.epoch_data with seed = Check seed }
    in
    { Zkapp_precondition.Protocol_state.accept with
      staking_epoch_data = epoch_data staking_epoch_seed
    ; next_epoch_data = epoch_data next_epoch_seed
    }

  let run ~config:_ network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let node = Network.block_producer_exn network "node-a" in
    let node_uri = Network.Node.get_ingress_uri node in
    let fish1_kp = (Network.genesis_keypair_exn network "fish1").keypair in
    let fish1_pk = Signature_lib.Public_key.compress fish1_kp.public_key in
    let keymap =
      Signature_lib.Public_key.Compressed.Map.singleton fish1_pk
        fish1_kp.private_key
    in
    let wait_for_zkapp_rejected zkapp_command =
      let with_timeout =
        Wait_condition.with_timeouts ~soft_timeout:(Network_time_span.Slots 4)
          ~hard_timeout:(Network_time_span.Slots 8)
      in
      wait_for t @@ with_timeout
      @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures:true
           ~zkapp_command
    in
    let rec wait_until_epoch ~target_epoch ~remaining_blocks =
      let current_epoch = (network_state t).epoch in
      if current_epoch >= target_epoch then return ()
      else if remaining_blocks <= 0 then
        Malleable_error.hard_error_format
          "Timed out waiting for epoch %d; current epoch is %d" target_epoch
          current_epoch
      else
        let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 1) in
        wait_until_epoch ~target_epoch ~remaining_blocks:(remaining_blocks - 1)
    in
    let%bind () =
      section_hard "Wait for node to initialize"
        (wait_for t (Wait_condition.nodes_to_initialize [ node ]))
    in
    let%bind.Deferred zkapp_command =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        mk_forest
          [ mk_node
              (mk_account_update_body Signature No fish1_kp Token_id.default 0
                 ~increment_nonce:true
                 ~preconditions:
                   { Account_update.Preconditions.network =
                       stale_epoch_seed_precondition
                   ; account =
                       Zkapp_precondition.Account.nonce (Account.Nonce.of_int 1)
                   ; valid_while = Ignore
                   } )
              []
          ]
        |> mk_zkapp_command ~memo:"stale epoch seed precondition"
             ~fee:12_000_000 ~fee_payer_pk:fish1_pk
             ~fee_payer_nonce:Account.Nonce.zero
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    let%bind () =
      section_hard "Wait until the chain crosses into epoch 1"
        (wait_until_epoch ~target_epoch:1 ~remaining_blocks:20)
    in
    let%bind () =
      section_hard "Replay stale epoch-0 seed precondition after epoch boundary"
        (send_zkapp ~logger node_uri zkapp_command)
    in
    section_hard
      "Confirm cross-epoch stale seed precondition is correctly rejected"
      (wait_for_zkapp_rejected zkapp_command)
end
