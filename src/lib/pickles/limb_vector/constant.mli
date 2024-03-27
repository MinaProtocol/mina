type 'n t = (int64, 'n) Pickles_types.Vector.t [@@deriving sexp_of]

val to_bits : 'a t -> bool list

module Hex64 : sig
  include module type of Core_kernel.Int64

  type t = int64

  (** [to_hex t] converts [t] to its hex-string representation.

      This is a "pure" hexadecimal representation, i.e., it does NOT sport any
      prefix like 'Ox' or '#x'.
   *)
  val to_hex : t -> string

  (** [of_hex s] converts a "pure" hexadecimal string representation into
      {!type:t}.

      [s] should not contain any prefix information.

      @raise Invalid_argument if the string is not convertible
   *)
  val of_hex : string -> t

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving compare, sexp, yojson, hash, equal, bin_shape, bin_io]

      include Pickles_types.Sigs.VERSIONED
    end
  end
end

module Make (N : Pickles_types.Nat.Intf) : sig
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
