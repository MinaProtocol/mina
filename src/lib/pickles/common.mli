val wrap_domains : proofs_verified:int -> Import.Domains.Stable.V2.t

val actual_wrap_domain_size :
  log_2_domain_size:int -> Pickles_base.Proofs_verified.t

(** [when_profiling profiling default] returns [profiling] when environment
    variable [PICKLES_PROFILING] is set to anything else than [0] or [false],
    [default] otherwise.

    TODO: This function should use labels to avoid mistakenly interverting
    profiling and default cases.
 *)
val when_profiling : 'a -> 'a -> 'a

(** [time label f] times function [f] and prints the measured time to [stdout]
    prepended with [label], when profiling is set (see {!val:when_profiling}).

    Otherwise, it just runs [f].
 *)
val time : string -> (unit -> 'a) -> 'a

val tick_shifts : log2_size:int -> Pasta_bindings.Fp.t array

val tock_shifts : log2_size:int -> Pasta_bindings.Fq.t array

val group_map :
     (module Group_map.Field_intf.S_unchecked with type t = 'a)
  -> a:'a
  -> b:'a
  -> ('a -> 'a * 'a) Core_kernel.Staged.t

val bits_to_bytes : bool list -> string

(** [finite_exn v] returns [(a, b)] when [v] is {!val:Finite(a,b)},
    [Invalid_argument] otherwise.*)
val finite_exn : 'a Kimchi_types.or_infinity -> 'a * 'a

val ft_comm :
     add:('comm -> 'comm -> 'comm)
  -> scale:('comm -> 'scalar -> 'comm)
  -> negate:('comm -> 'comm)
  -> verification_key:'comm array Pickles_types.Plonk_verification_key_evals.t
  -> plonk:
       ( 'd
       , 'e
       , 'scalar
       , 'g
       , 'f
       , 'bool )
       Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
  -> t_comm:'comm array
  -> 'comm

val combined_evaluation :
     (module Snarky_backendless.Snark_intf.Run
        with type field = 'f
         and type field_var = 'v )
  -> xi:'v
  -> ('v, 'v Snarky_backendless.Boolean.t) Pickles_types.Opt.t array list
  -> 'v

module Max_degree : sig
  val wrap_log2 : int

  val step : int

  val step_log2 : int
end

module Shifts : sig
  val tick1 : Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.Shift.t

  val tock2 : Backend.Tock.Field.t Pickles_types.Shifted_value.Type2.Shift.t
end

module Lookup_parameters : sig
  type ('a, 'b) zero_value :=
    ( Import.Challenge.Constant.t
    , 'a
    , Impls.Wrap.Field.Constant.t Pickles_types.Shifted_value.Type2.t
    , 'b Pickles_types.Shifted_value.Type2.t )
    Composition_types.Zero_values.t

  val tick_zero :
    (Impls.Step.Field.t, Impls.Step.Field.t * Impls.Step.Boolean.var) zero_value

  val tock_zero : (Impls.Wrap.Field.t, Impls.Wrap.Field.t) zero_value
end

(** Inner Product Argument *)
module Ipa : sig
  type 'a challenge :=
    ( Import.Challenge.Constant.t Import.Scalar_challenge.t
      Import.Bulletproof_challenge.t
    , 'a )
    Pickles_types.Vector.t

  type ('a, 'b) compute_sg := 'a challenge -> 'b * 'b

  module Wrap : sig
    val compute_challenge :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tock.Field.t

    val endo_to_field :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tock.Field.t

    val compute_challenges :
      'a challenge -> (Backend.Tock.Field.t, 'a) Pickles_types.Vector.t

    val compute_sg : ('a, Pasta_bindings.Fp.t) compute_sg
  end

  module Step : sig
    val compute_challenge :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tick.Field.t

    val endo_to_field :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tick.Field.t

    val compute_challenges :
      'a challenge -> (Backend.Tick.Field.t, 'a) Pickles_types.Vector.t

    val compute_sg : ('a, Pasta_bindings.Fq.t) compute_sg

    val accumulator_check :
         ( (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t)
         * (Pasta_bindings.Fp.t, 'a) Pickles_types.Vector.t )
         list
      -> bool Promise.t
  end
end

val hash_messages_for_next_step_proof :
     app_state:('a -> Kimchi_pasta.Basic.Fp.Stable.Latest.t Core_kernel.Array.t)
  -> ( Backend.Tock.Curve.Affine.t array
     (* the type for the verification key *)
     , 'a
     (* the state of the application *)
     , ( Kimchi_pasta.Basic.Fp.Stable.Latest.t
         * Kimchi_pasta.Basic.Fp.Stable.Latest.t
       , 'n )
       Pickles_types.Vector.t
     (* challenge polynomial commitments. We use the full parameter type to
        restrict the size of the vector to be the same than the one for the next
        parameter which are the bulletproof challenges *)
     , ( (Kimchi_pasta.Basic.Fp.Stable.Latest.t, 'm) Pickles_types.Vector.t
       , 'n
       (* size of the vector *) )
       Pickles_types.Vector.t
     (* bulletproof challenges *) )
     Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
  -> Import.Types.Digest.Constant.t

val tick_public_input_of_statement :
     max_proofs_verified:'max_proofs_verified Pickles_types.Nat.t
  -> 'max_proofs_verified Impls.Step.statement
  -> Backend.Tick.Field.Vector.elt list

val tock_public_input_of_statement :
     feature_flags:
       Pickles_types.Opt.Flag.t Pickles_types.Plonk_types.Features.Full.t
  -> ( Limb_vector.Challenge.Constant.t
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
       option
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
       option
     , bool
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , ( Limb_vector.Challenge.Constant.t
         Kimchi_backend_common.Scalar_challenge.t
         Composition_types.Bulletproof_challenge.t
       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
     , Composition_types.Branch_data.t )
     Import.Types.Wrap.Statement.In_circuit.t
  -> Backend.Tock.Field.Vector.elt list

val tock_unpadded_public_input_of_statement :
     feature_flags:
       Pickles_types.Opt.Flag.t Pickles_types.Plonk_types.Features.Full.t
  -> ( Limb_vector.Challenge.Constant.t
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
       option
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
       option
     , bool
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , ( Limb_vector.Challenge.Constant.t
         Kimchi_backend_common.Scalar_challenge.t
         Composition_types.Bulletproof_challenge.t
       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
     , Composition_types.Branch_data.t )
     Import.Types.Wrap.Statement.In_circuit.t
  -> Backend.Tock.Field.Vector.elt list
