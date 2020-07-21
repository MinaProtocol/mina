[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

module Arg = struct
  type t = (Field.t, Inner_curve.Scalar.t) Signature_poly.Stable.Latest.t
  [@@deriving bin_io_unversioned]

  let description = "Signature"

  let version_byte = Base58_check.Version_bytes.signature
end

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    type t = (Field.t, Inner_curve.Scalar.t) Signature_poly.Stable.V1.t
    [@@deriving sexp, compare, eq, hash]

    type _unused = unit constraint t = Arg.t

    include Codable.Make_base58_check (Arg)

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
      let known_good_digest = "5581d593702a09f4418fe46bde1ca116" in
      Ppx_version_runtime.Serialization.check_serialization
        (module V1)
        signature known_good_digest

    [%%elif
    curve_size = 753]

    let%test "signature serialization v1 (curve_size=753)" =
      let signature =
        Quickcheck.random_value
          ~seed:(`Deterministic "signature serialization") V1.gen
      in
      let known_good_digest = "7cc56fd93cef313e1eef9fc83f55aedb" in
      Ppx_version_runtime.Serialization.check_serialization
        (module V1)
        signature known_good_digest

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
