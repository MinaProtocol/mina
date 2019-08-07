open Core_kernel
open Snark_bits
open Fold_lib
open Module_version
include Intf

module Make (N : sig
  type t [@@deriving bin_io, sexp, compare, hash, version]

  include Unsigned_extended.S with type t := t

  val random : unit -> t
end)
(Bits : Bits_intf.S with type t := N.t)
(Bits_snarkable : Snark_params.Tick.Snarkable.Bits.Small
                  with type Packed.value = N.t
                   and type Unpacked.value = N.t) =
struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = N.t
        [@@deriving bin_io, sexp, eq, compare, hash, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "nat_make"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

  include Comparable.Make (Stable.Latest)

  include (N : module type of N with type t := t)

  include Bits_snarkable

  let is_succ_var ~pred ~succ =
    let open Snark_params.Tick in
    let open Field in
    Checked.(
      equal
        ((pack_var pred :> Var.t) + Var.constant one)
        (pack_var succ :> Var.t))

  let min_var x y =
    let open Snark_params.Tick in
    let%bind c =
      Field.Checked.compare ~bit_length:length_in_bits
        (pack_var x :> Field.Var.t)
        (pack_var y :> Field.Var.t)
    in
    Bits_snarkable.if_ c.less_or_equal ~then_:x ~else_:y

  module Bits = Bits

  let fold t = Fold.group3 ~default:false (Bits.fold t)

  let length_in_triples = (length_in_bits + 2) / 3

  let gen =
    Quickcheck.Generator.map
      ~f:(fun n -> N.of_string (Bignum_bigint.to_string n))
      (Bignum_bigint.gen_incl Bignum_bigint.zero
         (Bignum_bigint.of_string N.(to_string max_int)))
end

module Make32 () : UInt32 = struct
  include Make (struct
              open Unsigned_extended
              include UInt32

              let random () =
                let mask = if Random.bool () then one else zero in
                let open UInt32.Infix in
                logor (mask lsl 31)
                  ( Int32.max_value |> Random.int32 |> Int64.of_int32
                  |> UInt32.of_int64 )
            end)
            (Bits.UInt32)
            (Bits.Snarkable.UInt32 (Snark_params.Tick))

  let to_uint32 = Unsigned_extended.UInt32.to_uint32

  let of_uint32 = Unsigned_extended.UInt32.of_uint32
end

module Make64 () : UInt64 = struct
  include Make (struct
              open Unsigned_extended
              include UInt64

              let random () =
                let mask = if Random.bool () then one else zero in
                let open UInt64.Infix in
                logor (mask lsl 63)
                  (Int64.max_value |> Random.int64 |> UInt64.of_int64)
            end)
            (Bits.UInt64)
            (Bits.Snarkable.UInt64 (Snark_params.Tick))

  let to_uint64 = Unsigned_extended.UInt64.to_uint64

  let of_uint64 = Unsigned_extended.UInt64.of_uint64
end
