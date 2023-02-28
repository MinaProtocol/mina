let string s = `String s

let array element array = `List (array |> Array.map element |> Array.to_list)

let prefixes =
  let open Hash_prefixes in
  `Assoc
    [ ("event", `String (zkapp_event :> string))
    ; ("events", `String (zkapp_events :> string))
    ; ("sequenceEvents", `String (zkapp_actions :> string))
    ; ("body", `String (zkapp_body :> string))
    ; ("accountUpdateCons", `String (account_update_cons :> string))
    ; ("accountUpdateNode", `String (account_update_node :> string))
    ; ("zkappMemo", `String (zkapp_memo :> string))
    ; ("signatureMainnet", `String (signature_mainnet :> string))
    ; ("signatureTestnet", `String (signature_testnet :> string))
    ; ("zkappUri", `String (zkapp_uri :> string))
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
    ; ("privateKey", `Int (Char.to_int private_key))
    ; ("signature", `Int (Char.to_int signature))
    ; ("transactionHash", `Int (Char.to_int transaction_hash))
    ; ("signedCommandV1", `Int (Char.to_int signed_command_v1))
    ]

let poseidon_params_kimchi =
  `Assoc
    [ ("mds", array (array string) Sponge.Params.pasta_p_kimchi.mds)
    ; ( "roundConstants"
      , array (array string) Sponge.Params.pasta_p_kimchi.round_constants )
    ; ("fullRounds", `Int Pickles.Tick_field_sponge.Inputs.rounds_full)
    ; ("partialRounds", `Int Pickles.Tick_field_sponge.Inputs.rounds_partial)
    ; ( "hasInitialRoundConstant"
      , `Bool Pickles.Tick_field_sponge.Inputs.initial_ark )
    ; ("stateSize", `Int Random_oracle.state_size)
    ; ("rate", `Int Random_oracle.rate)
    ; ("power", `Int Pickles.Tick_field_sponge.Inputs.alpha)
    ]

let poseidon_params_legacy =
  `Assoc
    [ ("mds", array (array string) Sponge.Params.pasta_p_legacy.mds)
    ; ( "roundConstants"
      , array (array string) Sponge.Params.pasta_p_legacy.round_constants )
    ; ("fullRounds", `Int Random_oracle.Legacy.Inputs.rounds_full)
    ; ("partialRounds", `Int Random_oracle.Legacy.Inputs.rounds_partial)
    ; ("hasInitialRoundConstant", `Bool Random_oracle.Legacy.Inputs.initial_ark)
    ; ("stateSize", `Int Random_oracle.Legacy.state_size)
    ; ("rate", `Int Random_oracle.Legacy.rate)
    ; ("power", `Int Random_oracle.Legacy.Inputs.alpha)
    ]

let constants =
  [ ("prefixes", prefixes)
  ; ("versionBytes", version_bytes)
  ; ("poseidonParamsKimchiFp", poseidon_params_kimchi)
  ; ("poseidonParamsLegacyFp", poseidon_params_legacy)
  ]

let () =
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
