open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

let%test_unit "check_two_elements_are_never_the_same" =
  Quickcheck.test ~trials:50 Valid_size.zkapp_type_gen ~f:(fun (x, y) ->
      [%test_pred: Transaction_commitment.t * Transaction_commitment.t]
        (fun (a, b) -> not (phys_equal a b))
        (get_transaction_commitments @@ of_wire x) )
