open Pickles_types
module Opt = Opt

(** {2 Module aliases} *)

module Digest = Digest
module Spec = Spec
module Branch_data = Branch_data
module Bulletproof_challenge = Bulletproof_challenge
module Nvector = Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Wire = Wire
module Messages_for_next = Messages_for_next
module Reduced_messages_for_next = Reduced_messages_for_next
module Wrap_impl := Kimchi_pasta_snarky_backend.Wrap_impl

(** {2 Modules} *)

module Zero_values : sig
  type ('chal, 'fp) single = { challenge : 'chal; scalar : 'fp }

  type ('chal, 'chal_var, 'fp, 'fp_var) t =
    { value : ('chal, 'fp) single; var : ('chal_var, 'fp_var) single }
end

module Wrap = Wrap_proof

module Step : sig
  module Plonk_polys = Nat.N10

  module Bulletproof : sig
    include module type of Plonk_types.Openings.Bulletproof

    (** This is data that can be computed in linear time from the proof +
        statement.

        It doesn't need to be sent on the wire, but it does need to be provided
        to the verifier *)
    module Advice : sig
      type 'fq t = { b : 'fq; combined_inner_product : 'fq } [@@deriving hlist]

      val to_hlist : 'fq t -> (unit, 'fq -> 'fq -> unit) H_list.t

      val of_hlist : (unit, 'fq -> 'fq -> unit) H_list.t -> 'fq t
    end
  end

  module Proof_state : sig
    module Deferred_values = Step_deferred_values

    module Messages_for_next_wrap_proof =
      Wrap.Proof_state.Messages_for_next_wrap_proof
    module Messages_for_next_step_proof = Wrap.Messages_for_next_step_proof

    module Per_proof = Step_per_proof

    type ('unfinalized_proofs, 'messages_for_next_step_proof) t =
      { unfinalized_proofs : 'unfinalized_proofs
            (** A vector of the "per-proof" structures defined above, one for each proof
    that the step-circuit partially verifies. *)
      ; messages_for_next_step_proof : 'messages_for_next_step_proof
            (** The component of the proof accumulation state that is only computed on by the
          "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
      }
    [@@deriving sexp, compare, yojson, hlist]

    val spec :
         ('a, 'b, 'c) Spec.T.t
      -> ('d, 'e, 'c) Spec.T.t
      -> ( ('a * ('d * unit)) Hlist.HlistId.t
         , ('b * ('e * unit)) Hlist.HlistId.t
         , 'c )
         Spec.T.t

    val wrap_typ :
         assert_16_bits:(Wrap_impl.Field.t -> unit)
      -> (Opt.Flag.t Plonk_types.Features.t, 'n) Vector.t
      -> ('b, 'a) Wrap_impl.Typ.t
      -> ( ( ( ( Wrap_impl.Field.t
               , Wrap_impl.Field.t Scalar_challenge.t
               , 'b
               , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
                 , Backend.Tock.Rounds.n )
                 Vector.t
               , Wrap_impl.Field.t
               , Wrap_impl.Boolean.var )
               Per_proof.In_circuit.t
             , 'n )
             Vector.t
           , Wrap_impl.Field.t )
           t
         , ( ( ( Limb_vector.Challenge.Constant.t
               , Limb_vector.Challenge.Constant.t Scalar_challenge.t
               , 'a
               , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Backend.Tock.Rounds.n )
                 Vector.t
               , Digest.Constant.t
               , bool )
               Per_proof.In_circuit.t
             , 'n )
             Vector.t
           , Digest.Constant.t )
           t )
         Wrap_impl.Typ.t
  end

  module Statement : sig
    type ( 'unfinalized_proofs
         , 'messages_for_next_step_proof
         , 'messages_for_next_wrap_proof )
         t =
      { proof_state :
          ('unfinalized_proofs, 'messages_for_next_step_proof) Proof_state.t
      ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
      }
    [@@deriving sexp, compare, yojson]

    val to_data :
         ( ( ('a, 'b, 'c, 'e, 'f, 'g) Proof_state.Per_proof.In_circuit.t
           , 'h )
           Vector.t
         , 'i
         , 'j )
         t
      -> ( ( ( ('c, Nat.N5.n) Vector.t
             * ( ('f, Nat.N1.n) Vector.t
               * ( ('a, Nat.N2.n) Vector.t
                 * ( ('b, Nat.N3.n) Vector.t
                   * ('e * (('g, Nat.N1.n) Vector.t * unit)) ) ) ) )
             Hlist.HlistId.t
           , 'h )
           Vector.t
         * ('i * ('j * unit)) )
         Hlist.HlistId.t

    val of_data :
         ( ( ( ('a, Nat.N5.n) Vector.t
             * ( ('b, Nat.N1.n) Vector.t
               * ( ('c, Nat.N2.n) Vector.t
                 * ( ('d, Nat.N3.n) Vector.t
                   * ('e * (('f, Nat.N1.n) Vector.t * unit)) ) ) ) )
             Hlist.HlistId.t
           , 'h )
           Vector.t
         * ('i * ('j * unit)) )
         Hlist.HlistId.t
      -> ( ( ('c, 'd, 'a, 'e, 'b, 'f) Proof_state.Per_proof.In_circuit.t
           , 'h )
           Vector.t
         , 'i
         , 'j )
         t

    val spec :
         'b Nat.t
      -> 'c Nat.t
      -> ( ( ( ( ('f, Nat.N5.n) Vector.t
               * ( ('h, Nat.N1.n) Vector.t
                 * ( ('d, Nat.N2.n) Vector.t
                   * ( ('d Scalar_challenge.t, Nat.N3.n) Vector.t
                     * (('i, 'c) Vector.t * ((bool, Nat.N1.n) Vector.t * unit))
                     ) ) ) )
               Hlist.HlistId.t
             , 'b )
             Vector.t
           * ('h * (('h, 'b) Vector.t * unit)) )
           Hlist.HlistId.t
         , ( ( ( ('g, Nat.N5.n) Vector.t
               * ( ('j, Nat.N1.n) Vector.t
                 * ( ('e, Nat.N2.n) Vector.t
                   * ( ('e Scalar_challenge.t, Nat.N3.n) Vector.t
                     * (('k, 'c) Vector.t * (('bool2, Nat.N1.n) Vector.t * unit))
                     ) ) ) )
               Hlist.HlistId.t
             , 'b )
             Vector.t
           * ('j * (('j, 'b) Vector.t * unit)) )
           Hlist.HlistId.t
         , < bool1 : bool
           ; bool2 : 'bool2
           ; bulletproof_challenge1 : 'i
           ; bulletproof_challenge2 : 'k
           ; challenge1 : 'd
           ; challenge2 : 'e
           ; digest1 : 'h
           ; digest2 : 'j
           ; field1 : 'f
           ; field2 : 'g
           ; .. > )
         Spec.T.t
  end
end

module Challenges_vector : sig
  type 'n t = (Wrap_impl.Field.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant : sig
    type 'n t = (Wrap_impl.Field.Constant.t Wrap_bp_vec.t, 'n) Vector.t
  end
end

(** Concrete (non-versioned) records mirroring
    [Pickles.Reduced_messages_for_next_proof_over_same_field]. *)

(** Alias for
 ** {!val:Pickles_base.Side_loaded_verification_key.index_to_field_elements} *)
val index_to_field_elements :
  'a Plonk_verification_key_evals.t -> g:('a -> 'b array) -> 'b array
