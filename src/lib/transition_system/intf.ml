open Snark_params
open Tuple_lib
open Fold_lib

module type Digest_intf = sig
  open Tick

  type t

  module Unchecked : sig
    type t

    val fold : t -> bool Triple.t Fold.t
  end

  val typ : (t, Unchecked.t) Typ.t

  val to_triples : t -> Boolean.var Triple.t list
end

module type Step_inputs_intf = sig
  open Tick

  (* The hash section for the previous state could be reused in either the squashed or nested approach.
      1. Squashed: Reuse when hashing the the previous state itself (when comparing against the previous_state_hash field)
      2. Nested: Reuse when hashing the new state.

      I believe squashed is better and saves about 1000 constraints, but it is difficult to implement.
  *)
  module Update : sig
    type t

    module Unchecked : sig
      type t
    end

    val typ : (t, Unchecked.t) Typ.t
  end

  module State : sig
    type t

    module Hash : sig
      include Digest_intf

      val is_base : t -> Boolean.var
    end

    module Unchecked : sig
      type t [@@deriving sexp]

      val hash : t -> Hash.Unchecked.t
    end

    val typ : (t, Unchecked.t) Typ.t

    val hash : t -> Hash.t

    val update :
      Hash.t * t -> Update.t -> Hash.t * t * [`Success of Boolean.var]
  end
end
