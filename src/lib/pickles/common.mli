module Unshifted_acc =
  Pickles_types.Pairing_marlin_types.Accumulator.Degree_bound_checks
  .Unshifted_accumulators

module Max_degree : sig
  val step : int

  val wrap : int
end

val tick_shifts :
     log2_size:Core_kernel.Int.t
  -> Marlin_plonk_bindings_pasta_fp.t
     Marlin_plonk_bindings_types.Plonk_verification_shifts.t

val tock_shifts :
     log2_size:Core_kernel.Int.t
  -> Marlin_plonk_bindings_pasta_fq.t
     Marlin_plonk_bindings_types.Plonk_verification_shifts.t

val wrap_domains : Import.Domains.t

val hash_pairing_me_only :
     app_state:('a -> Pasta__Basic.Fp.Stable.Latest.t Core_kernel.Array.t)
  -> ( Backend.Tock.Curve.Affine.t
     , 'a
     , ( Pasta__Basic.Fp.Stable.Latest.t * Pasta__Basic.Fp.Stable.Latest.t
       , 'b )
       Pickles_types.Vector.t
     , ( (Pasta__Basic.Fp.Stable.Latest.t, 'c) Pickles_types.Vector.t
       , 'd )
       Pickles_types.Vector.t )
     Import.Types.Pairing_based.Proof_state.Me_only.t
  -> ( Core_kernel.Int64.t
     , Composition_types__Digest.Limbs.n )
     Pickles_types.Vector.t

val hash_dlog_me_only :
     'n Pickles_types.Nat.t
  -> ( Backend.Tick.Curve.Affine.t
     , ( (Pasta__Basic.Fq.Stable.Latest.t, 'a) Pickles_types.Vector.t
       , 'n )
       Pickles_types.Vector.t )
     Import.Types.Dlog_based.Proof_state.Me_only.t
  -> ( Core_kernel.Int64.t
     , Composition_types__Digest.Limbs.n )
     Pickles_types.Vector.t

val dlog_pcs_batch :
     'total Pickles_types.Nat.t
     * ('n_branching, Pickles_types.Nat.N8.n, 'total) Pickles_types.Nat.Adds.t
  -> max_quot_size:'a
  -> ( 'a
     , 'total
     , Pickles_types.Vector.z Pickles_types.Vector.s )
     Pickles_types.Pcs_batch.t

module Pairing_pcs_batch : sig
  val beta_1 :
    ( int
    , Pickles_types__Nat.z Pickles_types__Nat.N5.plus_n Pickles_types__Nat.s
    , Pickles_types.Vector.z )
    Pickles_types.Pcs_batch.t

  val beta_2 :
    ( int
    , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n Pickles_types__Nat.s
    , Pickles_types.Vector.z )
    Pickles_types.Pcs_batch.t

  val beta_3 :
    ( int
    , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n Pickles_types__Nat.s
    , Pickles_types.Vector.z )
    Pickles_types.Pcs_batch.t
end

val when_profiling : 'a -> 'a -> 'a

val time : string -> (unit -> 'a) -> 'a

val bits_random_oracle : length:int -> String.t -> bool list

val bits_to_bytes : bool list -> string

val group_map :
     (module Group_map.Field_intf.S_unchecked with type t = 'a)
  -> a:'a
  -> b:'a
  -> ('a -> 'a * 'a) Core_kernel__.Import.Staged.t

module Shifts : sig
  val tock : Backend.Tock.Field.t Pickles_types.Shifted_value.Shift.t

  val tick : Backend.Tick.Field.t Pickles_types.Shifted_value.Shift.t
end

module Ipa : sig
  val compute_challenge :
       endo_to_field:('a -> 'b)
    -> (module Zexe_backend.Field.S with type t = 'f)
    -> 'a
    -> 'b

  val compute_challenges :
       endo_to_field:('a -> 'b)
    -> (module Zexe_backend.Field.S with type t = 'c)
    -> ('a Import.Bulletproof_challenge.t, 'd) Pickles_types.Vector.t
    -> ('b, 'd) Pickles_types.Vector.t

  module Wrap : sig
    val field : (module Zexe_backend.Field.S with type t = Backend.Tock.Field.t)

    val endo_to_field :
         Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
      -> Backend.Tock.Field.t

    val compute_challenge :
         Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
      -> Backend.Tock.Field.t

    val compute_challenges :
         ( Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Import.Bulletproof_challenge.t
         , 'a )
         Pickles_types.Vector.t
      -> (Backend.Tock.Field.t, 'a) Pickles_types.Vector.t

    val compute_sg :
         ( Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Import.Bulletproof_challenge.t
         , 'a )
         Pickles_types.Vector.t
      -> Marlin_plonk_bindings_pasta_fp.t * Marlin_plonk_bindings_pasta_fp.t
  end

  module Step : sig
    val field : (module Zexe_backend.Field.S with type t = Backend.Tick.Field.t)

    val endo_to_field :
         Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
      -> Backend.Tick.Field.t

    val compute_challenge :
         Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
      -> Backend.Tick.Field.t

    val compute_challenges :
         ( Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Import.Bulletproof_challenge.t
         , 'a )
         Pickles_types.Vector.t
      -> (Backend.Tick.Field.t, 'a) Pickles_types.Vector.t

    val compute_sg :
         ( Import.Challenge.Constant.t Pickles_types.Scalar_challenge.t
           Import.Bulletproof_challenge.t
         , 'a )
         Pickles_types.Vector.t
      -> Marlin_plonk_bindings_pasta_fq.t * Marlin_plonk_bindings_pasta_fq.t

    val accumulator_check :
         ( (Marlin_plonk_bindings_pasta_fq.t * Marlin_plonk_bindings_pasta_fq.t)
         * (Marlin_plonk_bindings_pasta_fp.t, 'a) Pickles_types.Vector.t )
         list
      -> bool Async_kernel.Deferred.t
  end
end

val tock_unpadded_public_input_of_statement :
     ( Limb_vector__Challenge.Constant.t
     , Limb_vector__Challenge.Constant.t Composition_types.Spec.Sc.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.t
     , 'a
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
     , ( Limb_vector__Challenge.Constant.t Import.Spec.Sc.t
         Composition_types__.Bulletproof_challenge.t
       , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
       Pickles_types__Hlist0.Id.t
     , Composition_types__.Index.t )
     Import.Types.Dlog_based.Statement.In_circuit.t
  -> Backend.Tock.Field.Vector.elt list

val tock_public_input_of_statement :
     ( Limb_vector__Challenge.Constant.t
     , Limb_vector__Challenge.Constant.t Composition_types.Spec.Sc.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.t
     , 'a
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
     , ( Limb_vector__Challenge.Constant.t Import.Spec.Sc.t
         Composition_types__.Bulletproof_challenge.t
       , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
       Pickles_types__Hlist0.Id.t
     , Composition_types__.Index.t )
     Import.Types.Dlog_based.Statement.In_circuit.t
  -> Backend.Tock.Field.Vector.elt list

val tick_public_input_of_statement :
     max_branching:'a Pickles_types.Nat.t
  -> ( ( ( Limb_vector__Challenge.Constant.t
         , Limb_vector__Challenge.Constant.t Composition_types.Spec.Sc.t
         , Impls.Step.Other_field.Constant.t Pickles_types.Shifted_value.t
         , ( Limb_vector__Challenge.Constant.t Import.Spec.Sc.t
             Composition_types__.Bulletproof_challenge.t
           , Pickles_types__Nat.z Backend.Tock.Rounds.plus_n )
           Pickles_types.Vector.t
           Pickles_types__Hlist0.Id.t
         , ( Limb_vector__Constant.Hex64.t
           , Composition_types__Digest.Limbs.n )
           Pickles_types__Vector.vec
         , bool )
         Composition_types.Pairing_based.Proof_state.Per_proof.In_circuit.t
       , 'a )
       Pickles_types.Vector.t
     , ( Limb_vector__Constant.Hex64.t
       , Composition_types__Digest.Limbs.n )
       Pickles_types__Vector.vec
       Pickles_types__Hlist0.Id.t
     , ( ( Limb_vector__Constant.Hex64.t
         , Composition_types__Digest.Limbs.n )
         Pickles_types__Vector.vec
       , 'a )
       Pickles_types.Vector.t
       Pickles_types__Hlist0.Id.t )
     Import.Types.Pairing_based.Statement.t
  -> Backend.Tick.Field.Vector.elt list

val index_commitment_length :
  Import.Domain.t -> max_degree:Core_kernel.Int.t -> int

val max_log2_degree : int

val max_quot_size :
  of_int:(int -> 'a) -> mul:('a -> 'b -> 'c) -> sub:('d -> 'a -> 'b) -> 'd -> 'c

val max_quot_size_int : int -> int
