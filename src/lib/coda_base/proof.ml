[%%import
"/src/config.mlh"]

open Core_kernel
open Pickles_types

let blockchain_dummy = Dummy_values.blockchain_proof

let transaction_dummy = Dummy_values.transaction_proof

module T = Pickles.Proof.Make (Nat.N2) (Nat.N2)

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type t = T.t [@@deriving sexp, bin_io, version {asserted}, yojson, compare]

    let to_latest = Fn.id
  end
end]

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]

let%test_module "proof-tests" =
  ( module struct
    (* we test the serializations, because the Of_stringable functor creates serializations from serializers
       in Tock_backend.Proof, which is not versioned
    *)

    [%%if
    curve_size = 255]

    let%test "proof serialization v1" =
      let proof = blockchain_dummy in
      let known_good_digest = "a02b4f4ad38bc5c0a51da3a39c3673b4" in
      Ppx_version_runtime.Serialization.check_serialization
        (module Stable.V1)
        proof known_good_digest

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end )
