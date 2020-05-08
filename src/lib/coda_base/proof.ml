[%%import
"/src/config.mlh"]

open Core_kernel
open Module_version
open Pickles_types

let dummy = Dummy_values.proof

module T = Pickles.Proof.Make (Nat.N2) (Nat.N2)

[%%versioned_binable
module Stable = struct
  module V1 = struct

    type t = T.t [@@deriving sexp, bin_io, version {asserted}, yojson, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp, yojson, compare]

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]

let%test_module "proof-tests" =
  ( module struct
    (* we test the serializations, because the Of_stringable functor creates serializations from serializers
       in Tock_backend.Proof, which is not versioned
    *)

    [%%if
    curve_size = 298]

    let%test "proof serialization v1" =
      let proof = dummy in
      (* TODOPR: what is this *)
      let known_good_hash =
        "\x22\x36\x54\x9F\x8A\x0A\xBC\x8C\x4E\x90\x22\x91\x30\x20\x4D\x4C\xE1\x11\x01\xD4\xBA\x6B\x38\xEE\x8B\x95\x51\x7E\x6C\x40\xA7\x88"
      in
      Serialization.check_serialization
        (module Stable.V1)
        proof known_good_hash

    [%%elif
    curve_size = 753]

    let%test "proof serialization v1" =
      let proof = dmmy in
      let known_good_hash =
        "\xA6\x52\x85\xCE\x46\xC0\xB9\x24\x99\xA2\x3C\x90\x54\xC8\xAE\x7B\x17\x3A\x99\x64\x94\x3A\xE7\x6C\x66\xD9\x48\x5E\x5D\xD4\x83\x3F"
      in
      Serialization.check_serialization
        (module Stable.V1)
        proof known_good_hash

    [%%else]

    let%test "proof serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end )
