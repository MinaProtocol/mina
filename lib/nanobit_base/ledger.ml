open Core
open Snark_params

include Merkle_ledger.Ledger.Make
    (struct
      type account = Account.t [@@deriving sexp]
      type hash = Tick.Pedersen.Digest.t [@@deriving sexp]

      let empty_hash =
        Tick.Pedersen.hash_bigstring (Bigstring.of_string "nothing up my sleeve")

      let merge t1 t2 =
        let open Tick.Pedersen in
        hash_fold params (fun ~init ~f ->
          let init = Digest.Bits.fold t1 ~init ~f in
          Digest.Bits.fold t2 ~init ~f)

      let hash_account account =
        Tick.Pedersen.hash_fold Tick.Pedersen.params
          (Account.fold_bits account)
    end)
    (struct let max_depth = ledger_depth end)
    (Public_key.Compressed)
