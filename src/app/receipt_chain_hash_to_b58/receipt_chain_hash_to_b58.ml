let () =
  let s = Stdlib.read_line () in
  let fp = Kimchi_backend.Pasta.Basic.Fp.of_string s in
  let receipt_chain_hash : Mina_base.Receipt.Chain_hash.t = fp in
  Format.printf "%s@." (Mina_base.Receipt.Chain_hash.to_base58_check receipt_chain_hash)
