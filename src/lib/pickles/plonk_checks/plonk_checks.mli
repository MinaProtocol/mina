type 'field vanishing_polynomial_domain =
  < vanishing_polynomial : 'field -> 'field >

type 'field plonk_domain =
  < vanishing_polynomial : 'field -> 'field
  ; shifts : 'field Pickles_types.Plonk_types.Shifts.t
  ; generator : 'field >

type 'field domain = < size : 'field ; vanishing_polynomial : 'field -> 'field >

module type Field_intf = sig
  type t

  val size_in_bits : int

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val inv : t -> t

  val negate : t -> t
end

type 'f field = (module Field_intf with type t = 'f)

val tick_lookup_constant_term_part : 'a Scalars.Env.t -> 'a

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
     't field
  -> endo:'t
  -> mds:'t array array
  -> field_of_hex:(string -> 't)
  -> domain:< generator : 't ; vanishing_polynomial : 't -> 't ; .. >
  -> srs_length_log2:int
  -> ('t, 't) Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
  -> ('t * 't, 'a) Pickles_types.Plonk_types.Evals.In_circuit.t
  -> 't Scalars.Env.t

module Make (Shifted_value : Pickles_types.Shifted_value.S) (Sc : Scalars.S) : sig
  val ft_eval0 :
       't field
    -> domain:< shifts : 't array ; .. >
    -> env:'t Scalars.Env.t
    -> ( 't
       , 't )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
    -> ('t * 't, 'a) Pickles_types.Plonk_types.Evals.In_circuit.t
    -> 't
    -> lookup_constant_term_part:('t Scalars.Env.t -> 't) option
    -> 't

  val derive_plonk :
       ?with_label:(string -> (unit -> 't) -> 't)
    -> 't field
    -> env:'t Scalars.Env.t
    -> shift:'t Shifted_value.Shift.t
    -> ( 't
       , 't )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
    -> ('t * 't, 'a) Pickles_types.Plonk_types.Evals.In_circuit.t
    -> ( 't
       , 't
       , 't Shifted_value.t
       , ( ( 't
           , 't Shifted_value.t )
           Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
           .Lookup
           .t
         , 'b )
         Pickles_types.Plonk_types.Opt.t )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t

  val checked :
       (module Snarky_backendless.Snark_intf.Run with type field = 't)
    -> shift:'t Snarky_backendless.Cvar.t Shifted_value.Shift.t
    -> env:'t Snarky_backendless.Cvar.t Scalars.Env.t
    -> ( 't Snarky_backendless.Cvar.t
       , 't Snarky_backendless.Cvar.t
       , 't Snarky_backendless.Cvar.t Shifted_value.t
       , ( ( 't Snarky_backendless.Cvar.t
           , 't Snarky_backendless.Cvar.t Shifted_value.t )
           Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
           .Lookup
           .t
         , 't Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t )
         Pickles_types.Plonk_types.Opt.t )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
    -> ( 't Snarky_backendless.Cvar.t * 't Snarky_backendless.Cvar.t
       , 'a )
       Pickles_types.Plonk_types.Evals.In_circuit.t
    -> 't Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
end

(** [Domain] is re-exported from library Pickles_base *)
module Domain = Pickles_base.Domain

module Scalars = Scalars
