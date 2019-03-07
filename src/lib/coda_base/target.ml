open Core_kernel
open Snark_params
open Snark_bits
open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type t = Tick.Field.t [@@deriving bin_io, sexp, eq, compare]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "target"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include Stable.Latest
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
