open Core_kernel
open Pickles_types
open Hlist
module Backend = Backend
module Sponge_inputs = Sponge_inputs
module Impls = Impls
module Inductive_rule = Inductive_rule
module Tag = Tag

module type Statement_intf = sig
  type field

  type t

  val to_field_elements : t -> field array
end

module type Statement_var_intf =
  Statement_intf with type field := Impls.Step.Field.t

module type Statement_value_intf =
  Statement_intf with type field := Impls.Step.field

module Verification_key : sig
  include Binable.S

  val dummy : t

  module Id : sig
    type t [@@deriving sexp, eq]

    val dummy : unit -> t
  end

  val load :
       cache:Key_cache.Spec.t list
    -> Id.t
    -> (t * [`Cache_hit | `Locally_generated]) Async.Deferred.Or_error.t
end

module type Proof_intf = sig
  type statement

  type t [@@deriving bin_io]

  val verification_key : Verification_key.t Lazy.t

  val id : Verification_key.Id.t Lazy.t

  val verify : (statement * t) list -> bool
end

module Proof : sig
  type ('max_width, 'mlmb) t

  val dummy : 'w Nat.t -> 'm Nat.t -> _ Nat.t -> ('w, 'm) t

  module Make (W : Nat.Intf) (MLMB : Nat.Intf) : sig
    type nonrec t = (W.n, MLMB.n) t [@@deriving bin_io, sexp, compare, yojson]
  end
end

module Statement_with_proof : sig
  type ('s, 'max_width, _) t = 's * ('max_width, 'max_width) Proof.t
end

val verify :
     (module Nat.Intf with type n = 'n)
  -> (module Statement_value_intf with type t = 'a)
  -> Verification_key.t
  -> ('a * ('n, 'n) Proof.t) list
  -> bool

module Prover : sig
  type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'proof) t =
       ?handler:(Snarky.Request.request -> Snarky.Request.response)
    -> ( 'prev_values
       , 'local_widths
       , 'local_heights )
       H3.T(Statement_with_proof).t
    -> 'a_value
    -> 'proof
end

module Provers : module type of H3_2.T (Prover)

module Dirty : sig
  type t = [`Cache_hit | `Generated_something | `Locally_generated]

  val ( + ) : t -> t -> t
end

module Cache_handle : sig
  type t

  val generate_or_load : t -> Dirty.t
end

(** This compiles a series of inductive rules defining a set into a proof
    system for proving membership in that set, with a prover corresponding
    to each inductive rule. *)
val compile :
     ?self:('a_var, 'a_value, 'max_branching, 'branches) Tag.t
  -> ?cache:Key_cache.Spec.t list
  -> ?disk_keys:(Cache.Step.Key.Verification.t, 'branches) Vector.t
                * Cache.Wrap.Key.Verification.t
  -> (module Statement_var_intf with type t = 'a_var)
  -> (module Statement_value_intf with type t = 'a_value)
  -> typ:('a_var, 'a_value) Impls.Step.Typ.t
  -> branches:(module Nat.Intf with type n = 'branches)
  -> max_branching:(module Nat.Add.Intf with type n = 'max_branching)
  -> name:string
  -> choices:(   self:('a_var, 'a_value, 'max_branching, 'branches) Tag.t
              -> ( 'prev_varss
                 , 'prev_valuess
                 , 'widthss
                 , 'heightss
                 , 'a_var
                 , 'a_value )
                 H4_2.T(Inductive_rule).t)
  -> ('a_var, 'a_value, 'max_branching, 'branches) Tag.t
     * Cache_handle.t
     * (module Proof_intf
          with type t = ('max_branching, 'max_branching) Proof.t
           and type statement = 'a_value)
     * ( 'prev_valuess
       , 'widthss
       , 'heightss
       , 'a_value
       , ('max_branching, 'max_branching) Proof.t )
       H3_2.T(Prover).t
