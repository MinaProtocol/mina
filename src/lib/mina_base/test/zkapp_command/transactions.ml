open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

let%test_module "valid_size" =
  ( module struct
    let genesis_constant_error : Genesis_constants.t =
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
      ; zkapp_transaction_cost_limit = 1.
      ; max_event_elements = 0
      ; max_action_elements = 0
      }

    let zkapp_type_gen =
      let open Quickcheck.Let_syntax in
      let%map wire = Zkapp_command.T.Stable.Latest.Wire.gen in
      Zkapp_command.T.Stable.Latest.of_wire wire

    let%test_unit "valid_size_errors" =
      Quickcheck.test zkapp_type_gen ~f:(fun x ->
          [%test_eq: unit Or_error.t]
            (Error (Error.of_string "zkapp transaction too expensive"))
            (valid_size ~genesis_constants:genesis_constant_error x) )
  end )
