open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib
open Unsigned

module type S_unchecked = sig
  type t [@@deriving sexp, compare, hash, yojson]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val max_value : t

  val length_in_bits : int

  val gen : t Quickcheck.Generator.t

  val zero : t

  val succ : t -> t

  val add : t -> t -> t

  val of_int : int -> t

  val to_int : t -> int

  (* Someday: I think this only does ones greater than zero, but it doesn't really matter for
    selecting the nonce *)

  val random : unit -> t

  val of_string : string -> t

  val to_string : t -> string

  module Bits : Bits_intf.Convertible_bits with type t := t

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val fold : t -> bool Triple.t Fold.t
end

module type S_checked = sig
  type unchecked

  open Snark_params.Tick
  open Bitstring_lib

  type var

  val constant : unchecked -> var

  type t = var

  val zero : t

  val succ : t -> (t, _) Checked.t

  val add : t -> t -> (t, _) Checked.t

  val is_succ : pred:t -> succ:t -> (Boolean.var, _) Checked.t

  val min : t -> t -> (t, _) Checked.t

  val of_bits : Boolean.var Bitstring.Lsb_first.t -> t

  val to_bits : t -> (Boolean.var Bitstring.Lsb_first.t, _) Checked.t

  val to_integer : t -> field Snarky_integer.Integer.t

  val succ_if : t -> Boolean.var -> (t, _) Checked.t

  val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t

  (** warning: this typ does not work correctly with the generic if_ *)
  val typ : (t, unchecked) Snark_params.Tick.Typ.t

  val equal : t -> t -> (Boolean.var, _) Checked.t

  val ( = ) : t -> t -> (Boolean.var, _) Checked.t

  val ( < ) : t -> t -> (Boolean.var, _) Checked.t

  val ( > ) : t -> t -> (Boolean.var, _) Checked.t

  val ( <= ) : t -> t -> (Boolean.var, _) Checked.t

  val ( >= ) : t -> t -> (Boolean.var, _) Checked.t

  module Unsafe : sig
    val of_integer : field Snarky_integer.Integer.t -> t
  end
end

module type S = sig
  open Bitstring_lib
  open Snark_params.Tick

  include S_unchecked

  module Checked : S_checked with type unchecked := t

  (** warning: this typ does not work correctly with the generic if_ *)
  val typ : (Checked.t, t) Snark_params.Tick.Typ.t

  val var_to_bits : Checked.t -> Boolean.var Bitstring.Lsb_first.t
end

module type UInt32 = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Unsigned_extended.UInt32.t
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  include S with type t = Stable.Latest.t

  val to_uint32 : t -> uint32

  val of_uint32 : uint32 -> t
end

module type UInt64 = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Unsigned_extended.UInt64.t
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  include S with type t = Stable.Latest.t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t
end

module type F = functor
  (N :sig
      
      type t [@@deriving bin_io, sexp, compare, hash]

      include Unsigned_extended.S with type t := t

      val random : unit -> t
    end)
  (Bits : Bits_intf.Convertible_bits with type t := N.t)
  -> S with type t := N.t and module Bits := Bits
