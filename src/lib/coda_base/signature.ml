[%%import
"../../config.mlh"]

open Core
open Module_version
open Snark_params.Tick

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Field.t * Inner_curve.Scalar.t
      [@@deriving sexp, eq, compare, hash, bin_io, version {asserted}]

      let description = "Signature"

      let version_byte = Base58_check.Version_bytes.signature
    end

    include T
    include Codable.Make_base58_check (T)
    include Registration.Make_latest_version (T)

    let gen =
      let open Quickcheck.Let_syntax in
      let%bind field = Field.gen in
      let%map scalar = Inner_curve.Scalar.gen in
      (field, scalar)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "signature"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)

  (* see lib/module_version/README-version-asserted.md *)
  module For_tests = struct
    [%%if
    curve_size = 298]

    let%test "signature serialization v1" =
      let signature =
        Quickcheck.random_value
          ~seed:(`Deterministic "signature serialization") V1.gen
      in
      let known_good_hash =
        "\xB1\x26\x22\x37\xFC\x21\xAF\x11\xF7\x07\x20\xF6\x08\x1F\x78\x67\x8A\x3C\x5F\x4B\xDF\x0A\x1B\xFB\x5E\x7D\x37\xC6\x85\x03\xB0\xCD"
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
        "\x02\x42\x8B\xBD\xA9\x2B\x25\x33\xFD\xE5\xBF\xEE\x31\x6D\x64\xAD\x3D\x70\xD3\xB8\x89\x87\x02\xC3\x80\x91\x19\xE3\x0B\x58\x41\xDC"
      in
      Serialization.check_serialization (module V1) signature known_good_hash

    [%%else]

    let%test "signature serialization v1" =
      failwith "No test for this curve size"

    [%%endif]
  end
end

include Stable.Latest
open Snark_params.Tick

type var = Field.Var.t * Inner_curve.Scalar.var

let dummy : t = (Field.one, Inner_curve.Scalar.one)
