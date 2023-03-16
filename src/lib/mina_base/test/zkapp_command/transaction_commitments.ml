open Core_kernel
open Mina_base.Zkapp_command
open Mina_base
open Snarky_backendless
open Snark_params.Tick

let%test_module "get_transaction_commitments" =
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

    let zkapp_type_gen =
      let open Quickcheck.Let_syntax in
      let%bind length = Int.gen_incl 1 1000 in
      let gen_call_forest =
        List.gen_with_length length
        @@ With_stack_hash.quickcheck_generator tree_gen
             Unit.quickcheck_generator
      in
      let%bind fee_payer = Account_update.Fee_payer.gen in
      let%bind account_updates = gen_call_forest in
      let%map memo = Signed_command_memo.gen in
      { T.Stable.V1.Wire.fee_payer; account_updates; memo }

    let%test_unit "check_two_elements_are_never_the_same" =
      Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun x ->
          [%test_pred: Transaction_commitment.t * Transaction_commitment.t]
            (fun (a, b) -> not (phys_equal a b))
            (get_transaction_commitments @@ of_wire x) )
  end )
