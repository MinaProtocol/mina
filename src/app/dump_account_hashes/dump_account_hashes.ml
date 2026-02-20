(* dump_account_hashes.ml - Standalone CLI tool to dump important account hash constants *)

open Core_kernel

let () =
  (* Get the default zkapp account digest *)
  let default_zkapp_digest =
    Lazy.force Mina_base.Zkapp_account.default_digest
  in

  (* Convert to string using the same format as used in ledger JSON implementation *)
  let digest_string = Snark_params.Tick.Field.to_string default_zkapp_digest in

  (* Create JSON object with the hash *)
  let json =
    `Assoc [ ("default_zkapp_account_digest", `String digest_string) ]
  in

  (* Print pretty JSON *)
  let pretty_string = Yojson.Basic.pretty_to_string json in
  Format.printf "%s@." pretty_string
