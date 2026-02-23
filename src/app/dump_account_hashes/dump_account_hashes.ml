(* dump_account_hashes.ml - Standalone CLI tool to dump important account hash constants *)

open Core_kernel

let input_to_json input =
  let field_elements_json =
    `List
      ( Array.to_list input.Random_oracle_input.Chunked.field_elements
      |> List.map ~f:(fun field ->
             `String (Snark_params.Tick.Field.to_string field) ) )
  in

  let packeds_json =
    `List
      ( Array.to_list input.packeds
      |> List.map ~f:(fun (field, bits) ->
             `List
               [ `String (Snark_params.Tick.Field.to_string field); `Int bits ] )
      )
  in
  `Assoc [ ("fieldElements", field_elements_json); ("packeds", packeds_json) ]

let packed_input_to_json input_packed =
  `List
    ( Array.to_list input_packed
    |> List.map ~f:(fun field ->
           `String (Snark_params.Tick.Field.to_string field) ) )

let () =
  (* Get the default zkapp account digest *)
  let default_zkapp_digest =
    Lazy.force Mina_base.Zkapp_account.default_digest
  in

  (* Get the dummy verification key hash *)
  let dummy_vk_hash_value = Mina_base.Verification_key_wire.dummy_vk_hash () in

  (* Get the zkapp_uri non-preimage hash *)
  let zkapp_uri_non_preimage =
    Lazy.force Mina_base.Zkapp_account.zkapp_uri_non_preimage_hash
  in

  let default_account_input = Mina_base.Account.(to_input empty) in
  let default_account_input_packed =
    Random_oracle.pack_input default_account_input
  in

  let default_zkapp_account_input =
    Mina_base.Zkapp_account.(to_input default)
  in
  let default_zkapp_account_input_packed =
    Random_oracle.pack_input default_zkapp_account_input
  in

  (* Convert to string using the same format as used in ledger JSON implementation *)
  let digest_string = Snark_params.Tick.Field.to_string default_zkapp_digest in
  let vk_hash_string = Snark_params.Tick.Field.to_string dummy_vk_hash_value in

  (* Create JSON object with the hashes *)
  let json =
    `Assoc
      [ ("default_zkapp_account_digest", `String digest_string)
      ; ("dummy_vk_hash", `String vk_hash_string)
      ; ( "zkapp_uri_non_preimage_hash"
        , `String (Snark_params.Tick.Field.to_string zkapp_uri_non_preimage) )
      ; ( "empty_zkapp_uri_hash"
        , `String
            ( Snark_params.Tick.Field.to_string
            @@ Mina_base.Zkapp_account.hash_zkapp_uri "" ) )
      ; ( "default_zkapp_account_input"
        , input_to_json default_zkapp_account_input )
      ; ( "default_zkapp_account_input_packed"
        , packed_input_to_json default_zkapp_account_input_packed )
      ; ("default_account_input", input_to_json default_account_input)
      ; ( "default_account_input_packed"
        , packed_input_to_json default_account_input_packed )
      ; ( "default_zkapp_account_hash"
        , `String
            (Snark_params.Tick.Field.to_string
               (Lazy.force Mina_base.Zkapp_account.default_digest) ) )
      ]
  in

  (* Print pretty JSON *)
  let pretty_string = Yojson.Basic.pretty_to_string json in
  Format.printf "%s@." pretty_string
