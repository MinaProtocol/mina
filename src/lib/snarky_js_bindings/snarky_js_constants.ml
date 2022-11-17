let string s = `String s

let array element array = `List (array |> Array.map element |> Array.to_list)

let prefixes =
  let open Hash_prefixes in
  `Assoc
    [ ("event", `String (zkapp_event :> string))
    ; ("events", `String (zkapp_events :> string))
    ; ("sequenceEvents", `String (zkapp_sequence_events :> string))
    ; ("body", `String (zkapp_body :> string))
    ; ("accountUpdateCons", `String (account_update_cons :> string))
    ; ("accountUpdateNode", `String (account_update_node :> string))
    ; ("zkappMemo", `String (zkapp_memo :> string))
    ]

let version_bytes =
  let open Base58_check.Version_bytes in
  let open Core_kernel in
  `Assoc
    [ ("tokenIdKey", `Int (Char.to_int token_id_key))
    ; ("receiptChainHash", `Int (Char.to_int receipt_chain_hash))
    ; ("ledgerHash", `Int (Char.to_int ledger_hash))
    ; ("epochSeed", `Int (Char.to_int epoch_seed))
    ; ("stateHash", `Int (Char.to_int state_hash))
    ; ("publicKey", `Int (Char.to_int non_zero_curve_point_compressed))
    ; ("userCommandMemo", `Int (Char.to_int user_command_memo))
    ]

let () =
  let constants =
    [ ("prefixes", prefixes)
    ; ("versionBytes", version_bytes)
    ; ("mds", array (array string) Sponge.Params.pasta_p_kimchi.mds)
    ; ( "roundConstants"
      , array (array string) Sponge.Params.pasta_p_kimchi.round_constants )
    ]
  in

  let to_js (key, value) =
    "let " ^ key ^ " = " ^ Yojson.Safe.pretty_to_string value ^ ";\n"
  in
  let content =
    "// @gen this file is generated - don't edit it directly\n" ^ "export { "
    ^ (List.map fst constants |> String.concat ", ")
    ^ " }\n\n"
    ^ (List.map to_js constants |> String.concat "")
  in

  print_endline content
