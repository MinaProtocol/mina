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

let%test_module "proof-tests" =
  ( module struct
    (* we test the serializations, because the Of_stringable functor creates serializations from serializers
       in Tock_backend.Proof, which is not versioned
    *)

    [%%if curve_size = 255]

    let%test "proof serialization v2" =
      let proof = blockchain_dummy in
      let known_good_digest = "e44a234e6a1f4b7044834e33d8509c1b" in
      Ppx_version_runtime.Serialization.check_serialization
        (module Stable.V2)
        proof known_good_digest

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end )
