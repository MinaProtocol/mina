(* user_command_generators.ml *)

(* generate User_command.t's, that is, either Signed_commands or
   Zkapp_command
*)

open Core_kernel
open Mina_base
module Ledger = Mina_ledger.Ledger
include User_command.Gen

let zkapp_command_with_ledger ?(ledger_init_state : Ledger.init_state option)
    ?num_keypairs ?max_account_updates ?max_token_updates ?account_state_tbl ?vk
    ?failure ~(genesis_constants : Genesis_constants.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) () =
  let ledger_depth = constraint_constants.ledger_depth in
  let open Quickcheck.Let_syntax in
  let open Signature_lib in
  (* Need a fee payer keypair, a keypair for the "balancing" account (so that the balance changes
     sum to zero), and max_account_updates * 2 keypairs, because all the other zkapp_command
     might be new and their accounts not in the ledger; or they might all be old and in the ledger

     We'll put the fee payer account and max_account_updates accounts in the
     ledger, and have max_account_updates keypairs available for new accounts
  *)
  let max_account_updates =
    Option.value max_account_updates
      ~default:Zkapp_command_generators.max_account_updates
  in
  let max_token_updates =
    Option.value max_token_updates
      ~default:Zkapp_command_generators.max_token_updates
  in
  let num_keypairs =
    Option.value num_keypairs
      ~default:((max_account_updates * 2) + (max_token_updates * 3) + 2)
  in
  let%bind new_keypairs =
    let existing_keypairs =
      let tbl = Public_key.Compressed.Hash_set.create () in
      Option.iter ledger_init_state ~f:(fun l ->
          Array.iter l ~f:(fun (kp, _balance, _nonce, _timing) ->
              Hash_set.add tbl (Public_key.compress kp.public_key) ) ) ;
      tbl
    in
    let rec go acc n =
      if n = 0 then return acc
      else
        let%bind kp =
          Quickcheck.Generator.filter Keypair.gen ~f:(fun kp ->
              not
                (Hash_set.mem existing_keypairs
                   (Public_key.compress kp.public_key) ) )
        in
        Hash_set.add existing_keypairs (Public_key.compress kp.public_key) ;
        go (kp :: acc) (n - 1)
    in
    go [] num_keypairs
  in
  let keymap =
    List.fold new_keypairs ~init:Public_key.Compressed.Map.empty
      ~f:(fun map { public_key; private_key } ->
        let key = Public_key.compress public_key in
        Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
  in
  let num_keypairs_in_ledger = num_keypairs / 2 in
  let keypairs_in_ledger = List.take new_keypairs num_keypairs_in_ledger in
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
    let min_cmd_fee = genesis_constants.minimum_user_command_fee in
    let min_balance =
      Currency.Fee.to_nanomina_int min_cmd_fee
      |> Int.( + ) 100_000_000_000_000_000
      |> Currency.Balance.of_nanomina_int_exn
    in
    (* max balance to avoid overflow when adding deltas *)
    let max_balance =
      let max_bal = Currency.Balance.of_mina_string_exn "2000000000.0" in
      match
        Currency.Balance.add_amount min_balance
          (Currency.Balance.to_amount max_bal)
      with
      | None ->
          failwith "zkapp_command_with_ledger: overflow for max_balance"
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
      ; set_verification_key = (Either, Mina_numbers.Txn_version.current)
      ; set_zkapp_uri = Either
      ; edit_action_state = Either
      ; set_token_symbol = Either
      ; increment_nonce = Either
      ; set_voting_for = Either
      ; set_timing = Either
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
  let fee_payer_keypair = List.hd_exn new_keypairs in
  let ledger = Ledger.create_ephemeral ~depth:ledger_depth () in
  Ledger.set_batch_accounts ledger
    (List.mapi accounts ~f:(fun i account ->
         (Ledger.Addr.of_int_exn ~ledger_depth i, account) ) ) ;
  (* to keep track of account states across transactions *)
  let account_state_tbl =
    Option.value account_state_tbl ~default:(Account_id.Table.create ())
  in
  let%bind zkapp_command =
    Zkapp_command_generators.gen_zkapp_command_from ~max_account_updates
      ~max_token_updates ~fee_payer_keypair ~keymap ~ledger ~account_state_tbl
      ?vk ?failure ~genesis_constants ~constraint_constants ()
  in
  let zkapp_command =
    Or_error.ok_exn
      (Zkapp_command.Valid.to_valid ~failed:false
         ~find_vk:
           (Zkapp_command.Verifiable.load_vk_from_ledger
              ~get:(Ledger.get ledger)
              ~location_of_account:(Ledger.location_of_account ledger) )
         zkapp_command )
  in
  (* include generated ledger in result *)
  return
    (User_command.Zkapp_command zkapp_command, fee_payer_keypair, keymap, ledger)

let sequence_zkapp_command_with_ledger ?ledger_init_state ?max_account_updates
    ?max_token_updates ?length ?vk ?failure ~genesis_constants
    ~constraint_constants () =
  let open Quickcheck.Let_syntax in
  let%bind length =
    match length with
    | Some n ->
        return n
    | None ->
        Quickcheck.Generator.small_non_negative_int
  in
  let max_account_updates =
    Option.value max_account_updates
      ~default:Zkapp_command_generators.max_account_updates
  in
  let max_token_updates =
    Option.value max_token_updates
      ~default:Zkapp_command_generators.max_token_updates
  in
  let num_keypairs = length * max_account_updates * 2 in
  (* Keep track of account states across multiple zkapp_command transaction *)
  let account_state_tbl = Account_id.Table.create () in
  let%bind zkapp_command, fee_payer_keypair, keymap, ledger =
    zkapp_command_with_ledger ?ledger_init_state ~num_keypairs
      ~max_account_updates ~max_token_updates ~account_state_tbl ?vk ?failure
      ~genesis_constants ~constraint_constants ()
  in
  let rec go zkapp_command_and_fee_payer_keypairs n =
    if n <= 1 then
      return
        ( (zkapp_command, fee_payer_keypair, keymap)
          :: List.rev zkapp_command_and_fee_payer_keypairs
        , ledger )
    else
      let%bind zkapp_command =
        Zkapp_command_generators.gen_zkapp_command_from ~max_account_updates
          ~max_token_updates ~fee_payer_keypair ~keymap ~ledger
          ~account_state_tbl ?vk ?failure ~genesis_constants
          ~constraint_constants ()
      in
      let valid_zkapp_command =
        Or_error.ok_exn
          (Zkapp_command.Valid.to_valid ~failed:false
             ~find_vk:
               (Zkapp_command.Verifiable.load_vk_from_ledger
                  ~get:(Ledger.get ledger)
                  ~location_of_account:(Ledger.location_of_account ledger) )
             zkapp_command )
      in
      let zkapp_command_and_fee_payer_keypairs' =
        ( User_command.Zkapp_command valid_zkapp_command
        , fee_payer_keypair
        , keymap )
        :: zkapp_command_and_fee_payer_keypairs
      in
      go zkapp_command_and_fee_payer_keypairs' (n - 1)
  in
  go [] length
