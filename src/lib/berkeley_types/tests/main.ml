open Core_kernel

(* The transaction id of `3.4.0`'s test "zkApp v1 hash from transaction id"
   in `Transaction_hash`: a Berkeley zkApp command with proof authorizations,
   serialised after a leading integer 1. *)
let zkapp_transaction_id_file = "zkapp_v1_transaction_id.txt"

(* The hash that test expects. *)
let zkapp_transaction_hash =
  "5JtWZqwvKEgSMSHbDhYXg6s76GhfBNscQtxLKXnT6YYTsUKQkcpV"

let zkapp_command_hash_matches_berkeley () =
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
    Berkeley_types.Zkapp_command.Stable.Latest.bin_read_t ~pos_ref buf
  in
  Alcotest.(check int) "bytes read" len !pos_ref ;
  Alcotest.(check string)
    "hash" zkapp_transaction_hash
    ( Berkeley_types.Zkapp_command.hash command
    |> Mina_transaction.Transaction_hash.to_base58_check )

let () =
  Alcotest.run "Berkeley types"
    [ ( "zkapp_command"
      , [ Alcotest.test_case "hash matches 3.4.0" `Quick
            zkapp_command_hash_matches_berkeley
        ] )
    ]
