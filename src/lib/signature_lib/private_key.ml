[%%import
"/src/config.mlh"]

open Core_kernel
open Async_kernel
open Module_version

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    type t = Inner_curve.Scalar.t [@@deriving sexp]

    let to_latest = Fn.id

    let to_yojson t = `String (Inner_curve.Scalar.to_string t)

    let of_yojson = function
      | `String s ->
          Ok (Inner_curve.Scalar.of_string s)
      | _ ->
          Error "Private_key.of_yojson expected `String"

    [%%ifdef
    consensus_mechanism]

    let gen =
      let open Bignum_bigint in
      Quickcheck.Generator.map
        (gen_uniform_incl one (Snark_params.Tick.Inner_curve.Scalar.size - one))
        ~f:Snark_params.Tock.Bigint.(Fn.compose to_field of_bignum_bigint)

    [%%else]

    let gen = Inner_curve.Scalar.gen

    [%%endif]
  end

  (* see lib/module_version/README-version-asserted.md *)
  module Tests = struct
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
        "\x61\xB5\xC7\xDD\x3F\x67\x72\xD4\x8F\x58\x59\xD9\xE2\x2B\x2C\x94\xDD\x09\x83\x50\x1E\x8E\x2E\x9E\xBD\x48\x94\x9D\xC9\x8B\x51\x0A"
      in
      Serialization.check_serialization (module V1) pk known_good_hash

    [%%else]

    let%test "private key serialization v1" =
      failwith "No test for this curve size"

    [%%endif]
  end
end]

type t = Stable.Latest.t [@@deriving yojson, sexp]

[%%define_locally
Stable.Latest.(gen)]

[%%ifdef
consensus_mechanism]

let create () =
  (* This calls into libsnark which uses /dev/urandom *)
  Tick.Inner_curve.Scalar.random ()

[%%else]

let create () = Quickcheck.random_value ~seed:`Nondeterministic gen

[%%endif]

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
