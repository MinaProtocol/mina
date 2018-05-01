open Core_kernel

module type S = sig
  type t
  [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, eq]
    end
  end

  val zero : t

  val succ : t -> t

  (* Someday: I think this only does ones greater than zero, but it doesn't really matter for
    selecting the nonce *)
  val random : unit -> t

  module Bits : Bits_intf.S with type t := t

  include Snark_params.Tick.Snarkable.Bits.Faithful
    with type Unpacked.value = t
     and type Packed.value = t
end

module type F = functor
  (N : sig
    type t [@@deriving bin_io, sexp, eq]
    include Unsigned_extended.S with type t := t
    val random : unit -> t
  end)
  (Bits : Bits_intf.S with type t := N.t)
  (Bits_snarkable : functor (Impl : Snarky.Snark_intf.S) -> Bits_intf.Snarkable.Faithful
       with type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
        and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
        and type boolean_var := Impl.Boolean.var
        and type Packed.var = Impl.Cvar.t
        and type Packed.value = N.t
        and type Unpacked.var = Impl.Boolean.var list
        and type Unpacked.value = N.t) ->
          S with type t := N.t
             and module Bits := Bits

module Make : F
module Make32 () : S with type t = Unsigned_extended.UInt32.t
module Make64 () : S with type t = Unsigned_extended.UInt64.t
