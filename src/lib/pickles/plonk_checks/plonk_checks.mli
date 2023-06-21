open Pickles_types

type 'field vanishing_polynomial_domain =
  < vanishing_polynomial : 'field -> 'field >

type 'field plonk_domain =
  < vanishing_polynomial : 'field -> 'field
  ; shifts : 'field Pickles_types.Plonk_types.Shifts.t
  ; generator : 'field >

type 'field domain = < size : 'field ; vanishing_polynomial : 'field -> 'field >

module type Bool_intf = sig
  type t

  val true_ : t

  val false_ : t

  val ( &&& ) : t -> t -> t

  val ( ||| ) : t -> t -> t

  val any : t list -> t
end

module type Field_intf = sig
  type t

  val size_in_bits : int

  val zero : t

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val inv : t -> t

  val negate : t -> t
end

module type Field_with_if_intf = sig
  include Field_intf

  type bool

  val if_ : bool -> then_:(unit -> t) -> else_:(unit -> t) -> t
end

type 'f field = (module Field_intf with type t = 'f)

val lookup_tables_used :
  Plonk_types.Opt.Flag.t Plonk_types.Features.t -> Plonk_types.Opt.Flag.t

val domain :
     't field
  -> shifts:(log2_size:int -> 't array)
  -> domain_generator:(log2_size:int -> 't)
  -> Pickles_base.Domain.t
  -> 't plonk_domain

val evals_of_split_evals :
     'a field
  -> zeta:'a
  -> zetaw:'a
  -> ('a array * 'a array) Pickles_types.Plonk_types.Evals.t
  -> rounds:int
  -> ('a * 'a) Pickles_types.Plonk_types.Evals.t

val scalars_env :
     (module Bool_intf with type t = 'b)
  -> (module Field_with_if_intf with type t = 't and type bool = 'b)
  -> ?chunk_index:int
  -> endo:'t
  -> mds:'t array array
  -> field_of_hex:(string -> 't)
  -> domain:< generator : 't ; vanishing_polynomial : 't -> 't ; .. >
  -> srs_length_log2:int
  -> ( 't
     , 't
     , 'b )
     Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
  -> ('t * 't, 'a) Pickles_types.Plonk_types.Evals.In_circuit.t
  -> 't Scalars.Env.t

module Make (Shifted_value : Pickles_types.Shifted_value.S) (_ : Scalars.S) : sig
  val ft_eval0 :
       't field
    -> ?chunk_index:int
    -> domain:< shifts : 't array ; .. >
    -> env:'t Scalars.Env.t
    -> ( 't
       , 't
       , 'b )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
    -> ('t * 't, 'a) Pickles_types.Plonk_types.Evals.In_circuit.t
    -> 't
    -> 't

  val derive_plonk :
       ?with_label:(string -> (unit -> 't) -> 't)
    -> ?chunk_index:int
    -> (module Field_intf with type t = 't)
    -> env:'t Scalars.Env.t
    -> shift:'t Shifted_value.Shift.t
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> ( 't
       , 't
       , 'b )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
    -> ('t * 't, 'a) Pickles_types.Plonk_types.Evals.In_circuit.t
    -> ( 't
       , 't
       , 't Shifted_value.t
       , ('t Shifted_value.t, 'b) Pickles_types.Plonk_types.Opt.t
       , ( 't
           Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
           .Lookup
           .t
         , 'b )
         Pickles_types.Plonk_types.Opt.t
       , 'b )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t

  val checked :
       (module Snarky_backendless.Snark_intf.Run with type field = 't)
    -> shift:'t Snarky_backendless.Cvar.t Shifted_value.Shift.t
    -> env:'t Snarky_backendless.Cvar.t Scalars.Env.t
    -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
    -> ( 't Snarky_backendless.Cvar.t
       , 't Snarky_backendless.Cvar.t
       , 't Snarky_backendless.Cvar.t Shifted_value.t
       , ( 't Snarky_backendless.Cvar.t Shifted_value.t
         , 't Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t )
         Pickles_types.Plonk_types.Opt.t
       , ( 't Snarky_backendless.Cvar.t
           Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
           .Lookup
           .t
         , 't Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t )
         Pickles_types.Plonk_types.Opt.t
       , 't Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
    -> ( 't Snarky_backendless.Cvar.t * 't Snarky_backendless.Cvar.t
       , 'a )
       Pickles_types.Plonk_types.Evals.In_circuit.t
    -> 't Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
end

(** [Domain] is re-exported from library Pickles_base *)
module Domain = Pickles_base.Domain

module Scalars = Scalars
