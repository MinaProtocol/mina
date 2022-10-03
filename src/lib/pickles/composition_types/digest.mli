module Limbs = Pickles_types.Nat.N4

type nat4 := Limbs.n

type 'a v := ('a, nat4) Pickles_types.Vector.vec

type vector := int64 v

(** *)
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

  type t = Limb_vector.Constant.Hex64.t A.t
  [@@deriving compare, sexp, yojson, hash, equal]

  val to_bits : vector -> bool list

  val of_bits : bool list -> vector

  val of_tock_field : Backend.Tock.Field.t -> vector

  val dummy : t

  val zero : t

  val to_tick_field : vector -> Backend.Tick.Field.t

  val to_tock_field : vector -> Backend.Tock.Field.t

  val of_tick_field : Backend.Tick.Field.t -> vector
end

(** *)
module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type t = Impl.Field.t

  val to_bits : t -> Impl.Boolean.var list

  module Unsafe : sig
    val to_bits_unboolean : t -> Impl.Boolean.var list
  end

  module Constant : sig
    include module type of Constant
  end

  val typ : (t, vector) Impl.Typ.t
end
