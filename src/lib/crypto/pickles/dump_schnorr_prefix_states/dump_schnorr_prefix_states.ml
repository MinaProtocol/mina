(** Print the 3-element `Hash_prefix_states.signature ~signature_kind`
 *  sponge-prefix state for each Mina signature kind (Mainnet, Testnet),
 *  hex-encoded LE for the PS-side `fromHexLe` parser.
 *
 *  One-shot helper to harvest the constants for
 *  `packages/schnorr/src/Data/Schnorr/ChainId.purs::signaturePrefix`.
 *  Re-run if `Hash_prefix_states.signature` ever changes (it shouldn't:
 *  the values are protocol-pinned).
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_prefix_states/dump_schnorr_prefix_states.exe
 *)

open Core_kernel
module Tick_field = Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field

let field_to_hex_le (x : Tick_field.t) : string =
  let bytes =
    Tick_field.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes
  in
  (* Bigint256 bytes are LE-ordered; PS `fromHexLe` consumes byte-LE hex. *)
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf
      (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let dump label kind =
  let p =
    Hash_prefix_states.signature ~signature_kind:kind
    |> Random_oracle.State.to_array
  in
  Printf.printf "-- %s\n" label ;
  Array.iteri p ~f:(fun i f ->
      Printf.printf "%s[%d] = %s\n" label i (field_to_hex_le (Obj.magic f)) )

let () =
  dump "Mainnet" Mina_signature_kind.Mainnet ;
  dump "Testnet" Mina_signature_kind.Testnet
