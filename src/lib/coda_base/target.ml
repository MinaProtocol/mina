[%%import
"/src/config.mlh"]

open Core_kernel
open Snark_params
open Snark_bits

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    type t = Tick.Field.t [@@deriving sexp, eq, compare]

    let to_latest = Fn.id

    let gen = Tick.Field.gen
  end

  (* see lib/module_version/README-version-asserted.md *)
  module Tests = struct
    [%%if
    curve_size = 298]

    let%test "target serialization v1" =
      let target =
        Quickcheck.random_value ~seed:(`Deterministic "target serialization")
          V1.gen
      in
      let known_good_hash =
        "\x37\xD5\xCC\x43\xEC\x44\xCB\x67\x2D\x85\x25\xC7\x61\xBD\x93\xD1\x57\x30\x95\x82\xBF\x1C\x1D\x08\x73\xA0\x8E\x4D\x7C\x25\x5B\x22"
      in
      Ppx_version.Serialization.check_serialization
        (module V1)
        target known_good_hash

    [%%elif
    curve_size = 753]

    let%test "target serialization v1" =
      let target =
        Quickcheck.random_value ~seed:(`Deterministic "target serialization")
          V1.gen
      in
      let known_good_hash =
        "\x15\x32\x2E\x00\x93\xA0\x40\x03\xF3\x4F\xF0\x70\xAA\xA4\x71\x25\x57\x89\xE7\x42\x51\x3B\x14\x6E\xCE\x35\x3B\x40\xF8\x35\xA0\x2C"
      in
      Ppx_version.Serialization.check_serialization
        (module V1)
        target known_good_hash

    [%%else]

    let%test "target serialization v1" = failwith "No test for this curve size"

    [%%endif]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, compare]

module Field = Tick.Field
module Bigint = Tick_backend.Bigint.R

let bit_length = Snark_params.target_bit_length

let max_bigint =
  Tick.Bigint.of_bignum_bigint
    Bignum_bigint.(pow (of_int 2) (of_int bit_length) - one)

let max = Bigint.to_field max_bigint

let constant = Tick.Field.Var.constant

let of_field x =
  assert (Bigint.compare (Bigint.of_field x) max_bigint <= 0) ;
  x

let to_bigint x = Tick.Bigint.to_bignum_bigint (Bigint.of_field x)

let of_bigint n =
  let x = Tick.Bigint.of_bignum_bigint n in
  assert (Bigint.compare x max_bigint <= 0) ;
  Bigint.to_field x

(* TODO: Use a "dual" variable to ensure the bit_length constraint is actually always
   enforced. *)
include Bits.Snarkable.Small
          (Tick)
          (struct
            let bit_length = bit_length
          end)

module Bits =
  Bits.Small (Tick.Field) (Tick.Bigint)
    (struct
      let bit_length = bit_length
    end)

open Tick

let var_to_unpacked (x : Field.Var.t) =
  Field.Checked.unpack ~length:bit_length x
