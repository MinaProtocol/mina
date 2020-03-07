[%%import
"/src/config.mlh"]

open Core_kernel
open Module_version

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

module Arg = struct
  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = (Field.t, Inner_curve.Scalar.t) Signature_poly.Stable.V1.t

      let to_latest = Fn.id

      let description = "Signature"

      let version_byte = Base58_check.Version_bytes.signature
    end

    module Tests = struct
      (* actual tests in Stable below *)
    end
  end]
end

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    type t = (Field.t, Inner_curve.Scalar.t) Signature_poly.Stable.V1.t
    [@@deriving sexp, compare, eq, hash]

    type _unused = unit constraint t = Arg.Stable.V1.t

    include Codable.Make_base58_check (Arg.Stable.V1)

    let to_latest = Fn.id

    let gen = Quickcheck.Generator.tuple2 Field.gen Inner_curve.Scalar.gen
  end

  module Tests = struct
    [%%if
    curve_size = 298]

    let%test "signature serialization v1 (curve_size=298)" =
      let signature =
        Quickcheck.random_value
          ~seed:(`Deterministic "signature serialization") V1.gen
      in
      let known_good_hash =
        "\xAB\x7E\xE6\x52\xB9\xF4\x6C\xEE\x7B\xAB\x77\x3E\x25\x49\x84\xF5\xD0\x6E\x27\xB7\x2B\xCB\x76\x6B\xE5\xAC\x74\xAB\x8A\xC6\x27\x42"
      in
      Serialization.check_serialization (module V1) signature known_good_hash

    [%%elif
    curve_size = 753]

    let%test "signature serialization v1 (curve_size=753)" =
      let signature =
        Quickcheck.random_value
          ~seed:(`Deterministic "signature serialization") V1.gen
      in
      let known_good_hash =
        "\xFE\x32\x2E\x97\x30\xE8\x41\xA5\x8E\xC3\xCD\x85\xB1\x12\x8D\x41\x82\x99\xB5\x43\x00\x42\xDF\x10\xD6\xF0\xEC\x33\x38\x77\x2B\x50"
      in
      Serialization.check_serialization (module V1) signature known_good_hash

    [%%else]

    let%test "signature serialization v1" =
      failwith "No test for this curve size"

    [%%endif]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash]

let dummy = (Field.one, Inner_curve.Scalar.one)

[%%ifdef
consensus_mechanism]

type var = Field.Var.t * Inner_curve.Scalar.var

[%%endif]

[%%define_locally
Stable.Latest.(of_base58_check_exn, of_base58_check, of_yojson, to_yojson)]
