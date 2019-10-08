[%%import
"../../config.mlh"]

open Core_kernel
open Async_kernel
open Snark_params
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Tick.Inner_curve.Scalar.t
      [@@deriving bin_io, sexp, version {asserted}]

      let to_yojson t = `String (Tick.Inner_curve.Scalar.to_string t)
    end

    include T
    include Registration.Make_latest_version (T)

    let gen =
      let open Bignum_bigint in
      Quickcheck.Generator.map
        (gen_uniform_incl one (Snark_params.Tick.Inner_curve.Scalar.size - one))
        ~f:Snark_params.Tock.Bigint.(Fn.compose to_field of_bignum_bigint)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "private_key"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)

  (* see lib/module_version/README-version-asserted.md *)
  module For_tests = struct
    [%%if
    curve_size = 298]

    let%test "private key serialization v1" =
      let pk =
        Quickcheck.random_value ~seed:(`Deterministic "private key seed v1")
          V1.gen
      in
      let known_good_hash =
        "\xB5\xFE\x88\xB3\x7E\xDD\x30\x25\xA2\xB5\x00\x69\xCA\x0E\xE3\xC4\xAC\x17\x57\x40\xAD\x85\x40\xBB\x55\xDE\x3C\xB6\x30\xAD\x52\x5B"
      in
      Serialization.check_serialization (module V1) pk known_good_hash

    [%%elif
    curve_size = 753]

    let%test "private key serialization v1" =
      let pk =
        Quickcheck.random_value ~seed:(`Deterministic "private key seed v1")
          V1.gen
      in
      let known_good_hash =
        "\xB5\xFE\x88\xB3\x7E\xDD\x30\x25\xA2\xB5\x00\x69\xCA\x0E\xE3\xC4\xAC\x17\x57\x40\xAD\x85\x40\xBB\x55\xDE\x3C\xB6\x30\xAD\x52\x5B"
      in
      Serialization.check_serialization (module V1) pk known_good_hash

    [%%else]

    let%test "private key serialization v1" =
      failwith "No test for this curve size"

    [%%endif]
  end
end

type t = Stable.Latest.t [@@deriving to_yojson, sexp]

[%%define_locally
Stable.Latest.(gen)]

let create () =
  (* This calls into libsnark which uses /dev/urandom *)
  Tick.Inner_curve.Scalar.random ()

let of_bigstring_exn = Binable.of_bigstring (module Stable.Latest)

let to_bigstring = Binable.to_bigstring (module Stable.Latest)

module Base58_check = Base58_check.Make (struct
  let description = "Private key"

  let version_byte = Base58_check.Version_bytes.private_key
end)

let to_base58_check t =
  Base58_check.encode (to_bigstring t |> Bigstring.to_string)

let of_base58_check_exn s =
  let decoded = Base58_check.decode_exn s in
  decoded |> Bigstring.of_string |> of_bigstring_exn
