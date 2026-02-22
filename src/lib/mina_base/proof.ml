open Core_kernel

let blockchain_dummy = lazy (Dummy_values.blockchain_proof ())

let transaction_dummy = lazy (Dummy_values.transaction_proof ())

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Pickles.Proof.Proofs_verified_2.Stable.V2.t
    [@@deriving equal, hash, sexp, yojson, compare]

    let to_latest = Fn.id

    let to_yojson_full = Pickles.Proof.Proofs_verified_2.to_yojson_full
  end
end]

[%%define_locally Stable.Latest.(to_yojson, of_yojson, to_yojson_full)]

module For_tests = struct
  open Proof_cache_tag

  let blockchain_dummy_tag =
    Lazy.map
      ~f:(fun dummy -> write_proof_to_disk (For_tests.create_db ()) dummy)
      blockchain_dummy

  let transaction_dummy_tag =
    Lazy.map
      ~f:(fun dummy -> write_proof_to_disk (For_tests.create_db ()) dummy)
      transaction_dummy
end
