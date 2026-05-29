(** Emit raw Schnorr signature test vectors for the OUT-OF-CIRCUIT
 *  verifier `Data.Schnorr.verify` (the pure PS port at
 *  `packages/schnorr/src/Data/Schnorr.purs`). No kimchi proof — just
 *  the signed tuple, so PS can cross-check its pure verifier against
 *  Mina's `Signature_lib.Schnorr.Chunked.sign` cheaply.
 *
 *  For each chain (Mainnet, Testnet), signs a handful of deterministic
 *  `(privateKey, message)` cases sweeping message lengths 1..4 (sk and
 *  message derived from small constants so the fixtures are
 *  reproducible — no churn on regen).
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_signatures/
 *              dump_schnorr_signatures.exe -- <output_dir>
 *
 *  Writes `signatures.json`:
 *    { "signatures":
 *        [ { "chain": "Mainnet" | "Testnet"
 *          , "public_key_x": "<hex LE>"
 *          , "public_key_y": "<hex LE>"
 *          , "message": ["<hex LE>", ...]
 *          , "r": "<hex LE>"          -- R.x, a Tick base-field value
 *          , "s": "<hex LE>"          -- Pallas scalar (s < q < p, so PS
 *                                        reads it as a base field losslessly)
 *          }
 *        , ...
 *        ]
 *    }
 *)

open Core_kernel
module Inner_curve = Pickles.Backend.Tick.Inner_curve
module Pallas_scalar = Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field
module Tick_field = Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field

let tick_field_to_hex_le (x : Tick_field.t) : string =
  let bytes = Tick_field.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes in
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf
      (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let pallas_scalar_to_hex_le (x : Pallas_scalar.t) : string =
  let bytes =
    Pallas_scalar.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes
  in
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf
      (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let chain_name = function
  | Mina_signature_kind.Mainnet ->
      "Mainnet"
  | Mina_signature_kind.Testnet ->
      "Testnet"
  | Mina_signature_kind.Other_network s ->
      "Other:" ^ s

let make_entry ~signature_kind ~sk ~msg_len : Yojson.Safe.t =
  let pk_point = Inner_curve.scale Inner_curve.one sk in
  let pk_x, pk_y = Inner_curve.to_affine_exn pk_point in
  let message = Array.init msg_len ~f:(fun j -> Tick_field.of_int (1 + j)) in
  let r, s =
    Signature_lib.Schnorr.Chunked.sign ~signature_kind sk
      (Random_oracle.Input.Chunked.field_elements message)
  in
  (* Sanity: the production unchecked verifier accepts what we emit. *)
  assert (
    Signature_lib.Schnorr.Chunked.verify ~signature_kind (r, s) pk_point
      (Random_oracle.Input.Chunked.field_elements message) ) ;
  `Assoc
    [ ("chain", `String (chain_name signature_kind))
    ; ("public_key_x", `String (tick_field_to_hex_le pk_x))
    ; ("public_key_y", `String (tick_field_to_hex_le pk_y))
    ; ( "message"
      , `List
          (Array.to_list
             (Array.map message ~f:(fun m -> `String (tick_field_to_hex_le m))) )
      )
    ; ("r", `String (tick_field_to_hex_le r))
    ; ("s", `String (pallas_scalar_to_hex_le s))
    ]

let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/schnorr/test/fixtures/schnorr_signatures"
  in
  Printf.printf "dump_schnorr_signatures: output_dir = %s\n" output_dir ;
  (* 4 cases per chain, deterministic: sk = 100 + i, message length 1 + i
     (fields 1..len). *)
  let entries =
    List.concat_map [ Mina_signature_kind.Mainnet; Mina_signature_kind.Testnet ]
      ~f:(fun kind ->
        List.init 4 ~f:(fun i ->
            let sk = Pallas_scalar.of_int (100 + i) in
            make_entry ~signature_kind:kind ~sk ~msg_len:(1 + i) ) )
  in
  let json = `Assoc [ ("signatures", `List entries) ] in
  let path = Filename.concat output_dir "signatures.json" in
  Out_channel.write_all path ~data:(Yojson.Safe.pretty_to_string json ^ "\n") ;
  Printf.printf "wrote %d entries to %s\n" (List.length entries) path
