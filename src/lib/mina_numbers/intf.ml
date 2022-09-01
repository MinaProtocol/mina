[%%import "/src/config.mlh"]

open Core_kernel
open Fold_lib
open Tuple_lib
open Unsigned
open Snark_bits
open Snark_params.Tick

module type S_unchecked = sig
  type t [@@deriving sexp, compare, hash, yojson]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  (* not automatically derived *)
  val dhall_type : Ppx_dhall_type.Dhall_type.t

  val max_value : t

  val length_in_bits : int

  val gen : t Quickcheck.Generator.t

  val gen_incl : t -> t -> t Quickcheck.Generator.t

  val zero : t

  val succ : t -> t

  val add : t -> t -> t

  val sub : t -> t -> t option

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

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val to_input_legacy : t -> (_, bool) Random_oracle.Legacy.Input.t

  val fold : t -> bool Triple.t Fold.t
end

[%%ifdef consensus_mechanism]

module type S_checked = sig
  type unchecked

  open Snark_params.Tick

  type var

  val constant : unchecked -> var

  type t = var

  val zero : t

  val succ : t -> t Checked.t

  val add : t -> t -> t Checked.t

  val mul : t -> t -> t Checked.t

  (** [sub_or_zero x y] computes [x - y].

    - If the argument to [`Underflow] is true, [x < y] and the returned integer
      value is pinned to [zero].
    - If the argument to [`Underflow] is false, [x >= y] and the returned
      integer value is equal to [x - y]
  *)
  val sub_or_zero : t -> t -> ([ `Underflow of Boolean.var ] * t) Checked.t

  (** [sub ~m x y] computes [x - y] and ensures that [0 <= x - y] *)
  val sub : t -> t -> t Checked.t

  val is_succ : pred:t -> succ:t -> Boolean.var Checked.t

  val min : t -> t -> t Checked.t

  val to_input : t -> Field.Var.t Random_oracle.Input.Chunked.t

  val to_input_legacy :
    t -> (_, Boolean.var) Random_oracle.Legacy.Input.t Checked.t

  val succ_if : t -> Boolean.var -> t Checked.t

  val if_ : Boolean.var -> then_:t -> else_:t -> t Checked.t

  (** warning: this typ does not work correctly with the generic if_ *)
  val typ : (t, unchecked) Snark_params.Tick.Typ.t

  val equal : t -> t -> Boolean.var Checked.t

  val div_mod : t -> t -> (t * t) Checked.t

  val ( = ) : t -> t -> Boolean.var Checked.t

  val ( < ) : t -> t -> Boolean.var Checked.t

  val ( > ) : t -> t -> Boolean.var Checked.t

  val ( <= ) : t -> t -> Boolean.var Checked.t

  val ( >= ) : t -> t -> Boolean.var Checked.t

  module Assert : sig
    val equal : t -> t -> unit Checked.t
  end

  val to_field : t -> Field.Var.t

  module Unsafe : sig
    val of_field : Field.Var.t -> t
  end
end

[%%endif]

module type S = sig
  include S_unchecked

  [%%ifdef consensus_mechanism]

  module Checked : S_checked with type unchecked := t

  (** warning: this typ does not work correctly with the generic if_ *)
  val typ : (Checked.t, t) Snark_params.Tick.Typ.t

  [%%endif]
end

module type UInt32_A = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  include S with type t := t

  val to_uint32 : t -> uint32

  val of_uint32 : uint32 -> t
end
[@@warning "-32"]

module type UInt32 = UInt32_A with type Stable.V1.t = Unsigned_extended.UInt32.t

module type UInt64_A = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  include S with type t := Stable.Latest.t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t
end
[@@warning "-32"]

module type UInt64 = UInt64_A with type Stable.V1.t = Unsigned_extended.UInt64.t

module type F = functor
  (N : sig
     type t [@@deriving bin_io, sexp, compare, hash]

     include Unsigned_extended.S with type t := t

     val random : unit -> t
   end)
  (Bits : Bits_intf.Convertible_bits with type t := N.t)
  -> S with type t := N.t and module Bits := Bits

[%%ifdef consensus_mechanism]

module type F_checked = functor
  (N : Unsigned_extended.S)
  (Bits : Bits_intf.Convertible_bits with type t := N.t)
  -> S_checked with type unchecked := N.t
[@@warning "-67"]

[%%endif]
