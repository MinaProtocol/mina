(* dump_account_hashes.ml - Standalone CLI tool to dump important account hash constants *)

open Core_kernel

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

  (* Convert to string using the same format as used in ledger JSON implementation *)
  let digest_string = Snark_params.Tick.Field.to_string default_zkapp_digest in
  let vk_hash_string = Snark_params.Tick.Field.to_string dummy_vk_hash_value in
  let zkapp_uri_string =
    Snark_params.Tick.Field.to_string zkapp_uri_non_preimage
  in

  (* Create JSON object with the hashes *)
  let json =
    `Assoc
      [ ("default_zkapp_account_digest", `String digest_string)
      ; ("dummy_vk_hash", `String vk_hash_string)
      ; ("zkapp_uri_non_preimage_hash", `String zkapp_uri_string)
      ]
  in

  (* Print pretty JSON *)
  let pretty_string = Yojson.Basic.pretty_to_string json in
  Format.printf "%s@." pretty_string
