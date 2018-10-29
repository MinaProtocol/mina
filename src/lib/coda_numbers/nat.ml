open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib

module type S = sig
  type t [@@deriving bin_io, sexp, compare, eq, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]
    end
  end

  val length_in_triples : int

  val gen : t Quickcheck.Generator.t

  val zero : t

  val succ : t -> t

  val of_int : int -> t

  val to_int : t -> int

  (* Someday: I think this only does ones greater than zero, but it doesn't really matter for
    selecting the nonce *)

  val random : unit -> t

  val of_string : string -> t

  val to_string : t -> string

  module Bits : Bits_intf.S with type t := t

  include
    Snark_params.Tick.Snarkable.Bits.Small
    with type Unpacked.value = t
     and type Packed.value = t

  val fold : t -> bool Triple.t Fold.t
end

module type F = functor
  (N :sig
      
      type t [@@deriving bin_io, sexp, compare, hash]

      include Unsigned_extended.S with type t := t

      val random : unit -> t
    end)
  (Bits : Bits_intf.S with type t := N.t)
  (Bits_snarkable :
     Snark_params.Tick.Snarkable.Bits.Small
     with type Packed.value = N.t
      and type Unpacked.value = N.t)
  -> S with type t := N.t and module Bits := Bits

module Make (N : sig
  type t [@@deriving bin_io, sexp, compare, hash]

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
      type t = N.t [@@deriving bin_io, sexp, eq, compare, hash]
    end
  end

  include Stable.V1

  include (N : module type of N with type t := t)

  include Bits_snarkable
  module Bits = Bits

  let fold t = Fold.group3 ~default:false (Bits.fold t)

  let length_in_triples = (length_in_bits + 2) / 3

  let gen =
    Quickcheck.Generator.map
      ~f:(fun n -> N.of_string (Bignum_bigint.to_string n))
      (Bignum_bigint.gen_incl Bignum_bigint.zero
         (Bignum_bigint.of_string N.(to_string max_int)))
end

module Make32 () : S with type t = Unsigned_extended.UInt32.t =
  Make (struct
      open Unsigned_extended
      include UInt32

      let random () =
        let mask = if Random.bool () then one else zero in
        let open UInt32.Infix in
        logor (mask lsl 31)
          (Int32.max_value |> Random.int32 |> Int64.of_int32 |> UInt32.of_int64)
    end)
    (Bits.UInt32)
    (Bits.Snarkable.UInt32 (Snark_params.Tick))

module Make64 () : S with type t = Unsigned_extended.UInt64.t =
  Make (struct
      open Unsigned_extended
      include UInt64

      let random () =
        let mask = if Random.bool () then one else zero in
        let open UInt64.Infix in
        logor (mask lsl 63) (Int64.max_value |> Random.int64 |> UInt64.of_int64)
    end)
    (Bits.UInt64)
    (Bits.Snarkable.UInt64 (Snark_params.Tick))
