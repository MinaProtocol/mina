[%%import
"/src/config.mlh"]

open Core_kernel
open Module_version
open Snark_params.Tick

module Arg = struct
  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = (Field.t, Inner_curve.Scalar.t) Signature_poly.Stable.V1.t

      let to_latest = Fn.id

      let description = "Signature"

      let version_byte = Base58_check.Version_bytes.signature
    end

    module Tests = struct end
  end]
end

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    type t = (Field.t, Inner_curve.Scalar.t) Signature_poly.Stable.V1.t
    [@@deriving sexp, compare, eq, hash]

    type unused = unit constraint t = Arg.Stable.V1.t

    let to_latest = Fn.id

    let description = "Signature"

    let version_byte = Base58_check.Version_bytes.signature

    let gen = Quickcheck.Generator.tuple2 Field.gen Inner_curve.Scalar.gen

    include Codable.Make_base58_check (Arg.Stable.V1)
  end

  module Tests = struct
    [%%if
    curve_size = 298]

    let%test "signature serialization v1" =
      let signature =
        Quickcheck.random_value
          ~seed:(`Deterministic "signature serialization") V1.gen
      in
      let known_good_hash =
        "\x60\x6E\x8F\x6D\xF1\x4B\x53\x0B\x0A\x90\x2D\xF9\x8B\x1B\x96\x5E\x4A\x15\x30\x20\xDA\x2F\x9D\xDC\x45\x4B\xBA\xE4\x5F\xC5\xAA\xCD"
      in
      Serialization.check_serialization (module V1) signature known_good_hash

    [%%elif
    curve_size = 753]

    let%test "signature serialization v1" =
      let signature =
        Quickcheck.random_value
          ~seed:(`Deterministic "signature serialization") V1.gen
      in
      let known_good_hash =
        "\x47\x02\xC9\x4E\x7B\xD0\x1C\x40\x37\xCE\x70\xF2\x14\x30\xFA\x1C\xDD\x33\x94\x3B\xA4\xC6\xCE\x3A\xE6\xF5\x77\x69\xA9\x3A\x16\xB8"
      in
      Serialization.check_serialization (module V1) signature known_good_hash

    [%%else]

    let%test "signature serialization v1" =
      failwith "No test for this curve size"

    [%%endif]
  end
end]

[%%define_locally
Stable.Latest.(of_base58_check_exn, of_base58_check, of_yojson, to_yojson)]

include Functor.Make (Snark_params.Tick)
