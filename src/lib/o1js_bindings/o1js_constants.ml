(**
  this file is used to generate the content of bindings/crypto/constants.ts
  these constants are therefore available to o1js and mina-signer
  -) without causing a runtime dependency on ocaml code
  -) without having to be regenerated at startup
 *)

open Core_kernel
module Field = Pickles.Impls.Step.Field.Constant

let string s = `String s

let field f = `String (Field.to_string f)

let array element array = `List (array |> Array.map ~f:element |> Array.to_list)

let ledger_merkle_tree_depth = 35

let prefixes =
  let open Hash_prefixes in
  `Assoc
    [ ("event", `String (zkapp_event :> string))
    ; ("events", `String (zkapp_events :> string))
    ; ("sequenceEvents", `String (zkapp_actions :> string))
    ; ("zkappBodyMainnet", `String (zkapp_body_mainnet :> string))
    ; ("zkappBodyTestnet", `String (zkapp_body_testnet :> string))
    ; ("accountUpdateCons", `String (account_update_cons :> string))
    ; ("accountUpdateNode", `String (account_update_node :> string))
    ; ("account", `String (account :> string))
    ; ("zkappAccount", `String (zkapp_account :> string))
    ; ("zkappMemo", `String (zkapp_memo :> string))
    ; ("signatureMainnet", `String (signature_mainnet :> string))
    ; ("signatureTestnet", `String (signature_testnet :> string))
    ; ("zkappUri", `String (zkapp_uri :> string))
    ; ("deriveTokenId", `String (derive_token_id :> string))
    ; ("sideLoadedVK", `String (side_loaded_vk :> string))
    ; ( "merkleTree"
      , `List
          (List.init ledger_merkle_tree_depth ~f:(fun idx ->
               `String (merkle_tree idx :> string) ) ) )
    ]

type hash_prefix_kind = Kimchi | Legacy

let prefix_hash_entry (kind : hash_prefix_kind) (s : string) =
  let s, fields =
    match kind with
    | Kimchi ->
        (s, Random_oracle.(State.to_array (salt s)))
    | Legacy ->
        (s, Random_oracle.Legacy.(State.to_array (salt s)))
  in
  ((s :> string), array field fields)

let prefix_hashes =
  let open Hash_prefixes in
  `Assoc
    (List.map ~f:(prefix_hash_entry Kimchi)
       ( [ (receipt_chain_user_command :> string)
         ; (receipt_chain_zkapp :> string)
         ; (coinbase :> string)
         ; (pending_coinbases :> string)
         ; (coinbase_stack_data :> string)
         ; (coinbase_stack_state_hash :> string)
         ; (coinbase_stack :> string)
         ; (checkpoint_list :> string)
         ; (merge_snark :> string)
         ; (base_snark :> string)
         ; (protocol_state :> string)
         ; (protocol_state_body :> string)
         ; (vrf_message :> string)
         ; (signature_mainnet :> string)
         ; (signature_testnet :> string)
         ; (vrf_output :> string)
         ; (vrf_evaluation :> string)
         ; (epoch_seed :> string)
         ; (transition_system_snark :> string)
         ; (account :> string)
         ; (zkapp_account :> string)
         ; (side_loaded_vk :> string)
         ; (zkapp_payload :> string)
         ; (zkapp_body_mainnet :> string)
         ; (zkapp_body_testnet :> string)
         ; (zkapp_precondition :> string)
         ; (zkapp_precondition_account :> string)
         ; (zkapp_precondition_protocol_state :> string)
         ; (account_update_account_precondition :> string)
         ; (account_update_cons :> string)
         ; (account_update_node :> string)
         ; (account_update_stack_frame :> string)
         ; (account_update_stack_frame_cons :> string)
         ; (zkapp_uri :> string)
         ; (zkapp_event :> string)
         ; (zkapp_events :> string)
         ; (zkapp_actions :> string)
         ; (zkapp_memo :> string)
         ; (zkapp_test :> string)
         ; (derive_token_id :> string)
         ; "CodaReceiptEmpty"
         ; "MinaZkappEventsEmpty"
         ; "MinaZkappActionsEmpty"
         ; "MinaZkappActionStateEmptyElt"
         ; "CoinbaseStack"
         ; "PendingCoinbaseMerkleTree"
         ]
       @ List.init ledger_merkle_tree_depth ~f:(fun idx ->
             (merkle_tree idx :> string) ) ) )

let prefix_hashes_legacy =
  let open Hash_prefixes in
  `Assoc
    (List.map ~f:(prefix_hash_entry Legacy)
       [ (receipt_chain_user_command :> string)
       ; (signature_mainnet :> string)
       ; (signature_testnet :> string)
       ] )

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

let protocol_versions =
  let open Protocol_version in
  `Assoc [ ("txnVersion", `Int (transaction current)) ]

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

let dummy_verification_key_hash () =
  Pickles.Side_loaded.Verification_key.dummy
  |> Mina_base.Zkapp_account.digest_vk
  |> Pickles.Impls.Step.Field.Constant.to_string

let mocks =
  `Assoc
    [ ("dummyVerificationKeyHash", string (dummy_verification_key_hash ())) ]

let constants =
  [ ("prefixes", prefixes)
  ; ("prefixHashes", prefix_hashes)
  ; ("prefixHashesLegacy", prefix_hashes_legacy)
  ; ("versionBytes", version_bytes)
  ; ("protocolVersions", protocol_versions)
  ; ("poseidonParamsKimchiFp", poseidon_params_kimchi)
  ; ("poseidonParamsLegacyFp", poseidon_params_legacy)
  ; ("mocks", mocks)
  ]

let () =
  let to_js (key, value) =
    "let " ^ key ^ " = " ^ Yojson.Safe.pretty_to_string value ^ ";\n"
  in
  let content =
    "// @gen this file is generated from `bindings/ocaml/o1js_constants.ml` - \
     don't edit it directly\n" ^ "export { "
    ^ (List.map ~f:fst constants |> String.concat ~sep:", ")
    ^ " }\n\n"
    ^ (List.map ~f:to_js constants |> String.concat ~sep:"")
  in

  print_endline content
