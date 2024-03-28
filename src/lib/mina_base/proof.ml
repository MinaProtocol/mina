[%%import "/src/config.mlh"]

open Core_kernel

let blockchain_dummy = Dummy_values.blockchain_proof

let transaction_dummy = Dummy_values.transaction_proof

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Pickles.Proof.Proofs_verified_2.Stable.V2.t
    [@@deriving sexp, yojson, compare]

    let to_latest = Fn.id

    let to_yojson_full = Pickles.Proof.Proofs_verified_2.to_yojson_full
  end
end]

[%%define_locally Stable.Latest.(to_yojson, of_yojson, to_yojson_full)]
