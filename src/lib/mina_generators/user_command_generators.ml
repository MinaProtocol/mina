(* user_command_generators.ml *)

(* generate User_command.t's, that is, either Signed_commands or
   Parties
*)

[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base
module Ledger = Mina_ledger.Ledger
include User_command.Gen

(* using Precomputed_values depth introduces a cyclic dependency *)
[%%inject "ledger_depth", ledger_depth]

let parties_with_ledger ?num_keypairs ?max_other_parties ?max_token_parties
    ?account_state_tbl ?vk ?failure () =
  let open Quickcheck.Let_syntax in
  let open Signature_lib in
  (* Need a fee payer keypair, a keypair for the "balancing" account (so that the balance changes
     sum to zero), and max_other_parties * 2 keypairs, because all the other parties
     might be new and their accounts not in the ledger; or they might all be old and in the ledger

     We'll put the fee payer account and max_other_parties accounts in the
     ledger, and have max_other_parties keypairs available for new accounts
  *)
  let max_other_parties =
    Option.value max_other_parties ~default:Parties_generators.max_other_parties
  in
  let max_token_parties =
    Option.value max_token_parties ~default:Parties_generators.max_token_parties
  in
  let num_keypairs =
    Option.value num_keypairs
      ~default:((max_other_parties * 2) + (max_token_parties * 3) + 2)
  in
  let keypairs = List.init num_keypairs ~f:(fun _ -> Keypair.create ()) in
  let keymap =
    List.fold keypairs ~init:Public_key.Compressed.Map.empty
      ~f:(fun map { public_key; private_key } ->
        let key = Public_key.compress public_key in
        Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
  in
  let num_keypairs_in_ledger = num_keypairs / 2 in
  let keypairs_in_ledger = List.take keypairs num_keypairs_in_ledger in
  let account_ids =
    List.map keypairs_in_ledger ~f:(fun { public_key; _ } ->
        Account_id.create (Public_key.compress public_key) Token_id.default )
  in
  let verification_key =
    match vk with
    | None ->
        With_hash.
          { data = Side_loaded_verification_key.dummy
          ; hash = Zkapp_account.dummy_vk_hash ()
          }
    | Some vk ->
        vk
  in
  let%bind balances =
    let min_cmd_fee = Mina_compile_config.minimum_user_command_fee in
    let min_balance =
      Currency.Fee.to_int min_cmd_fee
      |> Int.( + ) 100_000_000_000_000_000
      |> Currency.Balance.of_int
    in
    (* max balance to avoid overflow when adding deltas *)
    let max_balance =
      let max_bal = Currency.Balance.of_formatted_string "2000000000.0" in
      match
        Currency.Balance.add_amount min_balance
          (Currency.Balance.to_amount max_bal)
      with
      | None ->
          failwith "parties_with_ledger: overflow for max_balance"
      | Some _ ->
          max_bal
    in
    Quickcheck.Generator.list_with_length num_keypairs_in_ledger
      (Currency.Balance.gen_incl min_balance max_balance)
  in
  let account_ids_and_balances = List.zip_exn account_ids balances in
  let snappify_account (account : Account.t) : Account.t =
    (* TODO: use real keys *)
    let permissions =
      { Permissions.user_default with
        edit_state = Permissions.Auth_required.Either
      ; send = Either
      ; set_delegate = Either
      ; set_permissions = Either
      ; set_verification_key = Either
      ; set_zkapp_uri = Either
      ; edit_sequence_state = Either
      ; set_token_symbol = Either
      ; increment_nonce = Either
      ; set_voting_for = Either
      }
    in
    let verification_key = Some verification_key in
    let zkapp = Some { Zkapp_account.default with verification_key } in
    { account with permissions; zkapp }
  in
  (* half zkApp accounts, half non-zkApp accounts *)
  let accounts =
    List.mapi account_ids_and_balances ~f:(fun ndx (account_id, balance) ->
        let account = Account.create account_id balance in
        if ndx mod 2 = 0 then account else snappify_account account )
  in
  let fee_payer_keypair = List.hd_exn keypairs in
  let ledger = Ledger.create ~depth:ledger_depth () in
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
          () ) ;
  (* to keep track of account states across transactions *)
  let account_state_tbl =
    Option.value account_state_tbl ~default:(Account_id.Table.create ())
  in
  let%bind parties =
    Parties_generators.gen_parties_from ~max_other_parties ~max_token_parties
      ~fee_payer_keypair ~keymap ~ledger ~account_state_tbl ?vk ?failure ()
  in
  let parties =
    Option.value_exn
      (Parties.Valid.to_valid ~ledger ~get:Ledger.get
         ~location_of_account:Ledger.location_of_account parties )
  in
  (* include generated ledger in result *)
  return (User_command.Parties parties, fee_payer_keypair, keymap, ledger)

let sequence_parties_with_ledger ?max_other_parties ?max_token_parties ?length
    ?vk ?failure () =
  let open Quickcheck.Let_syntax in
  let%bind length =
    match length with
    | Some n ->
        return n
    | None ->
        Quickcheck.Generator.small_non_negative_int
  in
  let max_other_parties =
    Option.value max_other_parties ~default:Parties_generators.max_other_parties
  in
  let max_token_parties =
    Option.value max_token_parties ~default:Parties_generators.max_token_parties
  in
  let num_keypairs =
    (length * max_other_parties * 2) + (max_token_parties * 3)
  in
  (* Keep track of account states across multiple parties transaction *)
  let account_state_tbl = Account_id.Table.create () in
  let%bind parties, fee_payer_keypair, keymap, ledger =
    parties_with_ledger ~num_keypairs ~max_other_parties ~max_token_parties
      ~account_state_tbl ?vk ?failure ()
  in
  let rec go parties_and_fee_payer_keypairs n =
    if n <= 1 then
      return
        ( (parties, fee_payer_keypair, keymap)
          :: List.rev parties_and_fee_payer_keypairs
        , ledger )
    else
      let%bind parties =
        Parties_generators.gen_parties_from ~max_other_parties
          ~max_token_parties ~fee_payer_keypair ~keymap ~ledger
          ~account_state_tbl ?vk ?failure ()
      in
      let valid_parties =
        Option.value_exn
          (Parties.Valid.to_valid ~ledger ~get:Ledger.get
             ~location_of_account:Ledger.location_of_account parties )
      in
      let parties_and_fee_payer_keypairs' =
        (User_command.Parties valid_parties, fee_payer_keypair, keymap)
        :: parties_and_fee_payer_keypairs
      in
      go parties_and_fee_payer_keypairs' (n - 1)
  in
  go [] length
