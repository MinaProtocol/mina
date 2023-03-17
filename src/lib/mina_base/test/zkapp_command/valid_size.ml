open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

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

let zkapp_type_gen =
  let open Quickcheck.Let_syntax in
  let%bind length = Int.gen_incl 1 1000 in
  let gen_call_forest =
    List.gen_with_length length
    @@ With_stack_hash.quickcheck_generator tree_gen Unit.quickcheck_generator
  in
  let%bind fee_payer = Account_update.Fee_payer.gen in
  let%bind account_updates = gen_call_forest in
  let%map memo = Signed_command_memo.gen in
  ({ T.Stable.V1.Wire.fee_payer; account_updates; memo }, length)

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

(* Note that in the following tests the generated zkapp_type will have an account_updates (i.e. a call_forest)
   that is a list of variable length (say Length), but each element in that list will always have two events and two actions.
   This means that the number of total actions and total events for the zkapp_type will be 2 * Length for each.
   Thus, in order to generate an error, we just need the genesis file to be defined such that max_event_elements < 2 * Length and similarly for max_action_elements.*)

let%test_unit "valid_size_errors_expensive" =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      [%test_eq: unit Or_error.t]
        (Error (Error.of_string "zkapp transaction too expensive"))
        ( valid_size
            ~genesis_constants:(genesis_constant_error 1. (2 * y) (2 * y))
        @@ of_wire x ) )

let%test_unit "valid_size_errors_events" =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      [%test_eq: unit Or_error.t]
        (Error
           ( Error.of_string
           @@ sprintf "too many event elements (%d, max allowed is %d)" (2 * y)
                y ) )
        ( valid_size
            ~genesis_constants:(genesis_constant_error 100000. y (2 * y))
        @@ of_wire x ) )

let%test_unit "valid_size_errors_actions" =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      [%test_eq: unit Or_error.t]
        (Error
           ( Error.of_string
           @@ sprintf "too many sequence event elements (%d, max allowed is %d)"
                (2 * y) y ) )
        ( valid_size
            ~genesis_constants:(genesis_constant_error 100000. (2 * y) y)
        @@ of_wire x ) )

let%test_unit "returns ok" =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      [%test_eq: unit Or_error.t] (Ok ())
        ( valid_size
            ~genesis_constants:(genesis_constant_error 100000. (2 * y) (2 * y))
        @@ of_wire x ) )
