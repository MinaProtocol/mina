open Core_kernel

(* The transaction id of the Mesa release's test "zkApp v1 hash from
   transaction id" in `Transaction_hash`: a Mesa zkApp command with proof
   authorizations, serialised after a leading integer 1. *)
let zkapp_transaction_id_file = "zkapp_transaction_id.txt"

(* The hash that test expects. *)
let zkapp_transaction_hash =
  "5Ju9x9Wq7Thdv5m2bd6FP5cYvS8TU8CMi9JwezaafbVtNCZjPTn1"

let zkapp_command_hash_matches_mesa () =
  let serialised =
    In_channel.read_all zkapp_transaction_id_file
    |> String.strip |> Base64.decode_exn
  in
  let len = String.length serialised in
  let buf = Bin_prot.Common.create_buf len in
  Bin_prot.Common.blit_string_buf serialised buf ~len ;
  let pos_ref = ref 0 in
  Alcotest.(check int)
    "leading integer" 1
    (Bin_prot.Std.bin_read_int ~pos_ref buf) ;
  let command =
    Mesa_types.Zkapp_command.Stable.Latest.bin_read_t ~pos_ref buf
  in
  Alcotest.(check int) "bytes read" len !pos_ref ;
  Alcotest.(check string)
    "hash" zkapp_transaction_hash
    ( Mesa_types.Zkapp_command.hash command
    |> Mina_transaction.Transaction_hash.to_base58_check )

(* A Mesa update setting permissions converts to the current permissions by
   dropping the transaction version. *)
let update_permissions_drop_the_version () =
  let current = Mina_base.Permissions.user_default in
  let mesa : Mesa_types.Permissions.Stable.V2.t =
    { edit_state = current.edit_state
    ; access = current.access
    ; send = current.send
    ; receive = current.receive
    ; set_delegate = current.set_delegate
    ; set_permissions = current.set_permissions
    ; set_verification_key = (Proof, Mina_numbers.Txn_version.of_int 3)
    ; set_zkapp_uri = current.set_zkapp_uri
    ; edit_action_state = current.edit_action_state
    ; set_token_symbol = current.set_token_symbol
    ; increment_nonce = current.increment_nonce
    ; set_voting_for = current.set_voting_for
    ; set_timing = current.set_timing
    }
  in
  let update : Mesa_types.Account_update.Update.Stable.V2.t =
    let dummy = Mina_base.Account_update.Update.dummy in
    { app_state = dummy.app_state
    ; delegate = dummy.delegate
    ; verification_key = dummy.verification_key
    ; permissions = Set mesa
    ; zkapp_uri = dummy.zkapp_uri
    ; token_symbol = dummy.token_symbol
    ; timing = dummy.timing
    ; voting_for = dummy.voting_for
    }
  in
  assert (
    Mesa_types.Account_update.Update.Stable.V2.equal update
      ( Mesa_types.Account_update.Update.Stable.V2.to_yojson update
      |> Mesa_types.Account_update.Update.Stable.V2.of_yojson
      |> Result.ok_or_failwith ) ) ;
  match (Mesa_types.Account_update.Update.to_current update).permissions with
  | Set permissions ->
      [%test_eq: Mina_base.Permissions.t]
        { current with set_verification_key = Proof }
        permissions
  | Keep ->
      failwith "the update no longer sets permissions"

let () =
  Alcotest.run "Mesa types"
    [ ( "zkapp_command"
      , [ Alcotest.test_case "hash matches the Mesa release" `Quick
            zkapp_command_hash_matches_mesa
        ] )
    ; ( "account_update"
      , [ Alcotest.test_case "permissions drop the version" `Quick
            update_permissions_drop_the_version
        ] )
    ]
