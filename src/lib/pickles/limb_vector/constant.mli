type 'n t = (int64, 'n) Pickles_types.Vector.t [@@deriving sexp_of]

val to_bits : 'a t -> bool list

module Hex64 : sig
  include module type of Core_kernel.Int64

  type t = int64

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving compare, sexp, yojson, hash, equal, bin_shape, bin_io]

      include Pickles_types.Sigs.VERSIONED
    end
  end
end

(** *)
module Make (N : Pickles_types.Vector.Nat_intf) : sig
  module A : module type of Pickles_types.Vector.With_length (N)

  val length : int

  type t = (Hex64.t, N.n) Pickles_types.Vector.vec
  [@@deriving sexp, compare, yojson, hash, equal]

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val of_tick_field : Backend.Tick.Field.t -> t

  val of_tock_field : Backend.Tock.Field.t -> t

  val to_tick_field : t -> Backend.Tick.Field.t

  val to_tock_field : t -> Backend.Tock.Field.t

  val dummy : t

  val zero : t
end
