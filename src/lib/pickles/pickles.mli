open Core_kernel
open Pickles_types
open Hlist

module type Statement_intf = sig
  type field

  type t

  val to_field_elements : t -> field array
end

module type Statement_var_intf =
  Statement_intf with type field := Impls.Pairing_based.Field.t

module type Statement_value_intf = sig
  include Statement_intf with type field := Impls.Pairing_based.field

  include Binable.S with type t := t
end

module type Proof_intf = sig
  type statement

  type t [@@deriving bin_io]

  val statement : t -> statement

  val verify : t -> bool
end

module Prev_proof : sig
  type ('s, 'max_width, 'max_height) t
end

module Prover : sig
  type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'proof) t =
       ('prev_values, 'local_widths, 'local_heights) H3.T(Prev_proof).t
    -> 'a_value
    -> 'proof
end

(** This compiles a series of inductive rules defining a set into a proof
    system for proving membership in that set, with a prover corresponding
    to each inductive rule. *)
val compile :
     (module Statement_var_intf with type t = 'a_var)
  -> (module Statement_value_intf with type t = 'a_value)
  -> typ:('a_var, 'a_value) Impls.Pairing_based.Typ.t
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
     * (module Proof_intf
          with type t = ('a_value, 'max_branching, 'branches) Prev_proof.t
           and type statement = 'a_value)
     * ( 'prev_valuess
       , 'widthss
       , 'heightss
       , 'a_value
       , ('a_value, 'max_branching, 'branches) Prev_proof.t )
       H3_2.T(Prover).t
