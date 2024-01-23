open! Core
open Mina_transaction_logic.Transaction_applied
open Mina_base

let%test_module "supply_increase" =
  ( module struct
    let generator =
      let open Snark_params.Tick in
      let open Quickcheck.Generator.Let_syntax in
      let%bind prev_hash_input = Int.quickcheck_generator in
      let account_id = [] in
      let%bind payload = Signed_command_payload.gen
      and signer = Mina_base_import.Public_key.gen
      and signature : Signature.t Quickcheck.Generator.t =
        return Signature.dummy
      in
      let data_input : Signed_command.t =
        Signed_command.Poly.{ payload; signer; signature }
      in
      let user_command_input : Signed_command.t With_status.t =
        { With_status.data = data_input; status = Transaction_status.Applied }
      in
      let common_input : Signed_command_applied.Common.t =
        { Signed_command_applied.Common.user_command = user_command_input }
      in
      let signed_command_input =
        Signed_command_applied.
          { common = common_input
          ; body = Body.Payment { new_accounts = account_id }
          }
      in
      let command_input : Command_applied.t =
        Command_applied.Signed_command signed_command_input
      in
      let%map varying_input = return @@ Varying.Command command_input
      and previous_hash_input = return @@ Field.of_int prev_hash_input in
      { varying = varying_input; previous_hash = previous_hash_input }

    type signed_amount = Currency.Amount.Signed.t
    [@@deriving equal, sexp, compare]

    (* Note that the function supply_increase can return results other than zero, but I've specifically chosen the case when the accounts list is empty.
       When it's non-empty, the values are different and thus difficult to confirm using property-based testing.
       Also, because of the particular input type chosen (of data type command ) this also simplifies things somewhat,
       whereas other types (i.e. fee_transfer and coinbase) produce numerical values other than zero in the calculation. *)
    let%test_unit "supply_increase_command_input_always_gives_zero_when_no_account_ids"
        =
      Quickcheck.test generator ~f:(fun payload ->
          [%test_eq: signed_amount Or_error.t]
            (Or_error.return @@ Currency.Amount.Signed.zero)
            (supply_increase payload) )
  end )
