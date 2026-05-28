(** Emit byte-compat test vectors for `Schnorr.Chunked.Message.derive` —
 *  the deterministic-nonce derivation used by the PS port at
 *  `packages/schnorr/src/Data/Schnorr/Derive.purs::deriveNonce`.
 *
 *  For each chain (Mainnet, Testnet), generates `n` random
 *  `(privateKey, publicKey, message)` triples and records the
 *  Mina-computed nonce. PS reads the JSON and asserts byte-equality
 *  with its own `deriveNonce` output.
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_derive_fixtures/
 *              dump_schnorr_derive_fixtures.exe -- <output_dir>
 *
 *  Writes `derive_fixtures.json`:
 *    { "fixtures":
 *        [ { "chain": "Mainnet" | "Testnet"
 *          , "private_key": "<hex LE>"
 *          , "public_key_x": "<hex LE>"
 *          , "public_key_y": "<hex LE>"
 *          , "message": ["<hex LE>", ...]
 *          , "expected_nonce": "<hex LE>"
 *          }
 *        , ...
 *        ]
 *    }
 *)

open Core_kernel
module Tick = Pickles.Backend.Tick
module Inner_curve = Pickles.Backend.Tick.Inner_curve
module Pallas_scalar = Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field
module Tick_field = Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field

let tick_field_to_hex_le (x : Tick_field.t) : string =
  let bytes = Tick_field.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes in
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let pallas_scalar_to_hex_le (x : Pallas_scalar.t) : string =
  let bytes =
    Pallas_scalar.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes
  in
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let derive_for ~signature_kind ~private_key ~public_key ~message :
    Pallas_scalar.t =
  let t =
    Random_oracle.Input.Chunked.field_elements message
  in
  Signature_lib.Schnorr.Message.Chunked.derive ~signature_kind t
    ~private_key ~public_key

let chain_name = function
  | Mina_signature_kind.Mainnet ->
      "Mainnet"
  | Mina_signature_kind.Testnet ->
      "Testnet"
  | Mina_signature_kind.Other_network s ->
      "Other:" ^ s

let make_entry ~signature_kind ~msg_len : Yojson.Safe.t =
  let d = Pallas_scalar.random () in
  let pk_point = Inner_curve.scale Inner_curve.one d in
  let pk_x, pk_y = Inner_curve.to_affine_exn pk_point in
  let message = Array.init msg_len ~f:(fun _ -> Tick_field.random ()) in
  let nonce =
    derive_for ~signature_kind ~private_key:d ~public_key:pk_point ~message
  in
  `Assoc
    [ ("chain", `String (chain_name signature_kind))
    ; ("private_key", `String (pallas_scalar_to_hex_le d))
    ; ("public_key_x", `String (tick_field_to_hex_le pk_x))
    ; ("public_key_y", `String (tick_field_to_hex_le pk_y))
    ; ( "message"
      , `List
          (Array.to_list
             (Array.map message ~f:(fun m ->
                  `String (tick_field_to_hex_le m) ) ) ) )
    ; ("expected_nonce", `String (pallas_scalar_to_hex_le nonce))
    ]

let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/schnorr/test/fixtures/schnorr_derive"
  in
  Printf.printf "dump_schnorr_derive_fixtures: output_dir = %s\n" output_dir ;
  let n_per_chain = 8 in
  (* Sweep message lengths 1..4 to exercise the `pack_to_fields`
     packing across multiple bit-pack chunks. *)
  let entries =
    List.concat_map
      [ Mina_signature_kind.Mainnet; Mina_signature_kind.Testnet ]
      ~f:(fun kind ->
        List.init n_per_chain ~f:(fun i ->
            let msg_len = 1 + (i mod 4) in
            make_entry ~signature_kind:kind ~msg_len ) )
  in
  let json = `Assoc [ ("fixtures", `List entries) ] in
  let path = Filename.concat output_dir "derive_fixtures.json" in
  Out_channel.write_all path ~data:(Yojson.Safe.pretty_to_string json ^ "\n") ;
  Printf.printf "wrote %d entries to %s\n" (List.length entries) path
