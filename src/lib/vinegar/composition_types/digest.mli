(** Vectors of 4 limbs of int64 *)

module Limbs = Pickles_types.Nat.N4

type nat4 := Limbs.n

(** Alias for fixed typed-size vector of size 4 *)
type 'a v := ('a, nat4) Pickles_types.Vector.vec

module Constant : sig
  module A : sig
    type 'a t = 'a v [@@deriving compare, sexp, yojson, hash, equal]

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val of_list_exn : 'a list -> 'a t

    val to_list : 'a t -> 'a list
  end

  module Stable : sig
    module V1 : sig
      type t =
        Limb_vector.Constant.Hex64.Stable.V1.t
        Pickles_types.Vector.Vector_4.Stable.V1.t
      [@@deriving compare, sexp, yojson, hash, equal]

      include Pickles_types.Sigs.VERSIONED

      include Pickles_types.Sigs.Binable.S with type t := t

      val to_latest : 'a -> 'a
    end

    module Latest = V1
  end

  val length : int

  type t = Stable.Latest.t [@@deriving compare, sexp, yojson, hash, equal]

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val of_tock_field : Backend.Tock.Field.t -> t

  val dummy : t

  val zero : t

  val to_tick_field : t -> Backend.Tick.Field.t

  val to_tock_field : t -> Backend.Tock.Field.t

  val of_tick_field : Backend.Tick.Field.t -> t
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type t = Impl.Field.t

  val to_bits : t -> Impl.Boolean.var list

  module Unsafe : sig
    val to_bits_unboolean : t -> Impl.Boolean.var list
  end

  module Constant : sig
    include module type of Constant with type Stable.V1.t = Constant.Stable.V1.t
  end

  val typ : (t, Constant.t) Impl.Typ.t
end
