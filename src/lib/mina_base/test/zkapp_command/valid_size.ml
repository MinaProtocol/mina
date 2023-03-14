open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

let%test_module "valid_size" =
  ( module struct
    let tree_gen =
      let open Quickcheck.Let_syntax in
      let%map account_gen = Account_update.gen_with_events_and_actions in
      { Call_forest.Tree.account_update = account_gen
      ; account_update_digest = ()
      ; calls =
          ([] : ( (Account_update.t, unit, unit) Call_forest.tree
                , unit )
                With_stack_hash.Stable.V1.t
                list)
      }

    let zkapp_type_gen_fixed_length length =
      let gen_call_forest =
        List.gen_with_length length
        @@ With_stack_hash.quickcheck_generator tree_gen
             Unit.quickcheck_generator
      in
      let open Quickcheck.Let_syntax in
      let%bind fee_payer = Account_update.Fee_payer.gen in
      let%bind account_updates = gen_call_forest in
      let%map memo = Signed_command_memo.gen in
      { T.Stable.V1.Wire.fee_payer; account_updates; memo }

    let genesis_constant_error limit events actions : Genesis_constants.t =
      { protocol =
          { k = 5
          ; slots_per_epoch = 5
          ; slots_per_sub_window = 5
          ; delta = 5
          ; genesis_state_timestamp = Genesis_constants.of_time (Time.now ())
          }
      ; txpool_max_size = 5
      ; num_accounts = Some 1
      ; zkapp_proof_update_cost = 1.
      ; zkapp_signed_single_update_cost = 1.
      ; zkapp_signed_pair_update_cost = 1.
      ; zkapp_transaction_cost_limit = limit
      ; max_event_elements = events
      ; max_action_elements = actions
      }

    (* zkapp transaction too expensive *)
    let%test_unit "valid_size_errors" =
      Quickcheck.test ~trials:50 (zkapp_type_gen_fixed_length 100) ~f:(fun x ->
          [%test_eq: unit Or_error.t]
            (Error (Error.of_string "zkapp transaction too expensive"))
            ( valid_size ~genesis_constants:(genesis_constant_error 1. 200 200)
            @@ of_wire x ) )

    (* too many event elements *)
    let%test_unit "valid_size_errors_events" =
      Quickcheck.test ~trials:50 (zkapp_type_gen_fixed_length 100) ~f:(fun x ->
          [%test_eq: unit Or_error.t]
            (Error
               (Error.of_string
                  "too many event elements (200, max allowed is 10)" ) )
            ( valid_size ~genesis_constants:(genesis_constant_error 100. 10 200)
            @@ of_wire x ) )

    (* too many action elements *)
    let%test_unit "valid_size_errors_actions" =
      Quickcheck.test ~trials:50 (zkapp_type_gen_fixed_length 100) ~f:(fun x ->
          [%test_eq: unit Or_error.t]
            (Error
               (Error.of_string
                  "too many sequence event elements (200, max allowed is 10)" )
            )
            ( valid_size ~genesis_constants:(genesis_constant_error 100. 200 10)
            @@ of_wire x ) )

    (* returns OK *)
    let%test_unit "returns ok" =
      Quickcheck.test ~trials:50 (zkapp_type_gen_fixed_length 100) ~f:(fun x ->
          [%test_eq: unit Or_error.t] (Ok ())
            ( valid_size ~genesis_constants:(genesis_constant_error 100. 200 200)
            @@ of_wire x ) )
  end )
