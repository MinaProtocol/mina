(* user_command_generators.ml *)

(* generate User_command.t's, that is, either Signed_commands or
   Parties
*)

open Core_kernel
include User_command.Gen

let parties () =
  let open Quickcheck.Let_syntax in
  let open Signature_lib in
  (* Need a fee payer keypair, and max_other_parties * 2 keypairs, because
     all the other parties might be new and their accounts not in the ledger;
     or they might all be old and in the ledger

     We'll put the fee payer account and max_other_parties accounts in the
     ledger, and have max_other_parties keypairs available for new accounts
  *)
  let num_keypairs = (Snapp_generators.max_other_parties * 2) + 1 in
  let keypairs = List.init num_keypairs ~f:(fun _ -> Keypair.create ()) in
  let keymap =
    List.fold keypairs ~init:Public_key.Compressed.Map.empty
      ~f:(fun map { public_key; private_key } ->
        let key = Public_key.compress public_key in
        Public_key.Compressed.Map.add_exn map ~key ~data:private_key)
  in
  let num_keypairs_in_ledger = Snapp_generators.max_other_parties + 1 in
  let keypairs_in_ledger = List.take keypairs num_keypairs_in_ledger in
  let account_ids =
    List.map keypairs_in_ledger ~f:(fun { public_key; _ } ->
        Account_id.create (Public_key.compress public_key) Token_id.default)
  in
  let%bind balances =
    Quickcheck.Generator.list_with_length num_keypairs_in_ledger
      Currency.Balance.gen
  in
  let accounts =
    List.map2_exn account_ids balances ~f:(fun account_id balance ->
        Account.create account_id balance)
  in
  let fee_payer_keypair = List.hd_exn keypairs in
  let depth =
    Genesis_constants.Constraint_constants.for_unit_tests.ledger_depth
  in
  let ledger = Ledger.create ~depth () in
  List.iter2_exn account_ids accounts ~f:(fun acct_id acct ->
      match Ledger.get_or_create_account ledger acct_id acct with
      | Error err ->
          failwithf
            "parties: error adding account for account id: %s, error: %s@."
            (Account_id.to_yojson acct_id |> Yojson.Safe.to_string)
            (Error.to_string_hum err) ()
      | Ok (`Existed, _) ->
          failwithf "parties: account for account id already exists: %s@."
            (Account_id.to_yojson acct_id |> Yojson.Safe.to_string)
            ()
      | Ok (`Added, _) ->
          ()) ;
  let%bind protocol_state = Snapp_predicate.Protocol_state.gen in
  Quickcheck.Generator.map
    (Snapp_generators.gen_parties_from ~fee_payer_keypair ~keymap ~ledger
       ~protocol_state ()) ~f:(fun parties -> User_command.Parties parties)
