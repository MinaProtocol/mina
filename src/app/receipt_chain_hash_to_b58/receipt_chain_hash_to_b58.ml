open Core_kernel
open Mina_base

let () =
  let s = Stdlib.read_line () in
  let b58 =
    match Receipt.Chain_hash.of_base58_check s with
    | Ok _ ->
        s
    | Error _ ->
        let fp = Kimchi_backend.Pasta.Basic.Fp.of_string s in
        let receipt_chain_hash : Mina_base.Receipt.Chain_hash.t = fp in
        Receipt.Chain_hash.to_base58_check receipt_chain_hash
  in
  Format.printf "%s@." b58
