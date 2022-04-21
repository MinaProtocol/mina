open Core
open Signature_lib
open Mina_base
module U = Transaction_snark_tests.Util

let%test_module "Zkapp fuzzy tests" =
  ( module struct
    let%test_unit "gen_parties_from" =
      Test_util.with_randomness 123456789 (fun () ->
          let fee_payer_keypair = Keypair.create () in
          let fee_payer_pk = Public_key.compress fee_payer_keypair.public_key in
          let fee_payer_account_id =
            Account_id.create fee_payer_pk Token_id.default
          in
          let (initial_balance : Currency.Balance.t) =
            Currency.Balance.of_int 1_000_000_000_000
          in
          let (fee_payer_account : Account.t) =
            Account.create fee_payer_account_id initial_balance
          in
          let ledger = Mina_ledger.Ledger.create ~depth:10 () in
          Mina_ledger.Ledger.get_or_create_account ledger fee_payer_account_id
            fee_payer_account
          |> Or_error.ok_exn
          |> fun _ ->
          () ;
          let keys = List.init 1000 ~f:(fun _ -> Keypair.create ()) in
          let keymap =
            List.map (fee_payer_keypair :: keys)
              ~f:(fun { public_key; private_key } ->
                (Public_key.compress public_key, private_key))
            |> Public_key.Compressed.Map.of_alist_exn
          in
          Quickcheck.test ~trials:20
            (Mina_generators.Parties_generators.gen_parties_from
               ~protocol_state_view:U.genesis_state_view ~fee_payer_keypair
               ~keymap ~ledger ()) ~f:(fun parties ->
              U.apply_parties ledger [ parties ] |> fun _ -> ()
              (*
              Mina_ledger.Ledger.apply_parties_unchecked ~constraint_constants:U.constraint_constants
              ~state_view:U.genesis_state_view
                    ledger parties
                 |> Or_error.ok_exn |> (fun _ -> ())
              *)))
  end )
