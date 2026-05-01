open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Opt
module Wire = Wire

(* Internal alias preserving access to the local [Digest] module after the
   file-level [open Core_kernel] below shadows the unqualified name. *)
module Digest_ = Digest
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

let index_to_field_elements =
  Pickles_base.Side_loaded_verification_key.index_to_field_elements

module Zero_values = struct
  type ('chal, 'fp) single = { challenge : 'chal; scalar : 'fp }

  type ('chal, 'chal_var, 'fp, 'fp_var) t =
    { value : ('chal, 'fp) single; var : ('chal_var, 'fp_var) single }
end

module Wrap = struct
  module Proof_state = struct
    (** This module contains structures which contain the scalar-field elements that
        are required to finalize the verification of a proof that is partially verified inside
        a circuit.

        Each verifier circuit starts by verifying the parts of a proof involving group operations.
        At the end, there is a sequence of scalar-field computations it must perform. Instead of
        performing them directly, it exposes the values needed for those computations as a part of
        its own public-input, so that the next circuit can do them (since it will use the other curve on the cycle,
        and hence can efficiently perform computations in that scalar field). *)
    include Wire.Wrap.Proof_state

    module Deferred_values = Wrap_deferred_values

    (** The component of the proof accumulation state that is only computed on by the
        "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
    module Messages_for_next_wrap_proof = struct
      include Wire.Wrap.Proof_state.Messages_for_next_wrap_proof

      (** Wire-format polymorphic skeleton. Concrete records below name it
          explicitly via {!Poly} rather than [include]ing it. *)
      module Poly = Wire.Wrap.Proof_state.Messages_for_next_wrap_proof

      let to_field_elements (type g f)
          { challenge_polynomial_commitment; old_bulletproof_challenges }
          ~g1:(g1_to_field_elements : g -> f list) =
        Array.concat
          [ Vector.to_array old_bulletproof_challenges
            |> Array.concat_map ~f:Vector.to_array
          ; Array.of_list (g1_to_field_elements challenge_polynomial_commitment)
          ]

      let wrap_typ g1 chal ~length =
        Wrap_impl.Typ.of_hlistable
          [ g1; Vector.wrap_typ chal length ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      (** Wire-form (out-of-circuit) instantiation: the challenge polynomial
          commitment is pinned to a [Tick.Curve.Affine.t] curve point;
          ['bulletproof_challenges] (a vector-of-vectors) stays parametric
          because the outer length varies per [Max_proofs_verified] and the
          inner is the constant [Tock.Rounds.n]. *)
      module Constant = struct
        type 'bulletproof_challenges t =
          { challenge_polynomial_commitment : Backend.Tick.Curve.Affine.t
          ; old_bulletproof_challenges : 'bulletproof_challenges
          }

        let to_stable
            ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
              'bp t ) : (Backend.Tick.Curve.Affine.t, 'bp) Poly.t =
          { challenge_polynomial_commitment; old_bulletproof_challenges }

        let of_stable
            ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
              (Backend.Tick.Curve.Affine.t, 'bp) Poly.t ) : 'bp t =
          { challenge_polynomial_commitment; old_bulletproof_challenges }
      end

      let _ = fun (c : _ Constant.t) ->
        Constant.of_stable (Constant.to_stable c)

      (** Step-circuit (Tick) instantiation. The commitment is witnessed
          as a pair of Step field elements (affine coordinates). *)
      module Step = struct
        type 'bulletproof_challenges t =
          { challenge_polynomial_commitment :
              Step_impl.Field.t * Step_impl.Field.t
          ; old_bulletproof_challenges : 'bulletproof_challenges
          }

        let to_stable
            ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
              'bp t ) : (Step_impl.Field.t * Step_impl.Field.t, 'bp) Poly.t =
          { challenge_polynomial_commitment; old_bulletproof_challenges }

        let of_stable
            ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
              (Step_impl.Field.t * Step_impl.Field.t, 'bp) Poly.t ) : 'bp t =
          { challenge_polynomial_commitment; old_bulletproof_challenges }
      end

      let _ = fun (s : _ Step.t) -> Step.of_stable (Step.to_stable s)

      (** Wrap-circuit (Tock) instantiation. *)
      module Wrap = struct
        type 'bulletproof_challenges t =
          { challenge_polynomial_commitment :
              Wrap_impl.Field.t * Wrap_impl.Field.t
          ; old_bulletproof_challenges : 'bulletproof_challenges
          }

        let to_stable
            ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
              'bp t ) : (Wrap_impl.Field.t * Wrap_impl.Field.t, 'bp) Poly.t =
          { challenge_polynomial_commitment; old_bulletproof_challenges }

        let of_stable
            ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
              (Wrap_impl.Field.t * Wrap_impl.Field.t, 'bp) Poly.t ) : 'bp t =
          { challenge_polynomial_commitment; old_bulletproof_challenges }
      end

      let _ = fun (w : _ Wrap.t) -> Wrap.of_stable (Wrap.to_stable w)
    end

    module Minimal = struct
      include Wire.Wrap.Proof_state.Minimal
    end

    module In_circuit = struct
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fp_opt
           , 'lookup_opt
           , 'bool
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'fp_opt
          , 'lookup_opt
          , 'bool )
          Deferred_values.Plonk.In_circuit.t
        , 'scalar_challenge
        , 'fp
        , 'messages_for_next_wrap_proof
        , 'digest
        , 'bp_chals
        , 'index )
        Stable.Latest.t
      [@@deriving sexp, compare, yojson, hash, equal]

      let to_hlist, of_hlist = (to_hlist, of_hlist)

      let typ (type fp) ~dummy_scalar_challenge ~challenge ~scalar_challenge
          ~feature_flags (fp : (fp, _) Step_impl.Typ.t)
          messages_for_next_wrap_proof digest index =
        Step_impl.Typ.of_hlistable
          [ Deferred_values.In_circuit.typ ~dummy_scalar_challenge ~challenge
              ~scalar_challenge ~feature_flags fp index
          ; digest
          ; messages_for_next_wrap_proof
          ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      (** Step-circuit (Tick) instantiation of {!t}. Used by the var-side
          of [Per_proof_witness.t]. The [messages_for_next_wrap_proof] slot
          is [unit] because the per-proof witness records its mfn-wrap
          digest separately at the outer [Statement] level. *)
      module Step = struct
        type t =
          ( ( Step_impl.Field.t
            , Step_impl.Field.t Scalar_challenge.t
            , Step_impl.Field.t Shifted_value.Type1.t
            , ( Step_impl.Field.t Shifted_value.Type1.t
              , Step_impl.Boolean.var )
              Opt.t
            , (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
            , Step_impl.Boolean.var )
            Deferred_values.Plonk.In_circuit.t
          , Step_impl.Field.t Scalar_challenge.t
          , Step_impl.Field.t Shifted_value.Type1.t
          , unit
          , Step_impl.Field.t
          , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.Checked.Step.t )
          Stable.Latest.t

        let typ ~dummy_scalar_challenge ~challenge ~scalar_challenge
            ~feature_flags fp messages_for_next_wrap_proof digest index :
            (t, _) Step_impl.Typ.t =
          Step_impl.Typ.of_hlistable
            [ Deferred_values.In_circuit.typ ~dummy_scalar_challenge ~challenge
                ~scalar_challenge ~feature_flags fp index
            ; digest
            ; messages_for_next_wrap_proof
            ]
            ~var_to_hlist:Stable.Latest.to_hlist
            ~var_of_hlist:Stable.Latest.of_hlist
            ~value_to_hlist:Stable.Latest.to_hlist
            ~value_of_hlist:Stable.Latest.of_hlist
      end

      (** Out-of-circuit ("constant") instantiation of {!t}. Used by the
          value-side of [Per_proof_witness.Constant.t]. *)
      module Constant = struct
        type t =
          ( ( Limb_vector.Challenge.Constant.t
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , Backend.Tick.Field.t Shifted_value.Type1.t
            , Backend.Tick.Field.t Shifted_value.Type1.t option
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t option
            , bool )
            Deferred_values.Plonk.In_circuit.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , Backend.Tick.Field.t Shifted_value.Type1.t
          , unit
          , Digest_.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Stable.Latest.t
      end
    end

    let to_minimal
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          _ In_circuit.t ) ~to_option : _ Minimal.t =
      { deferred_values = Deferred_values.to_minimal ~to_option deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }

    (** Wire-format polymorphic skeleton. Concrete records below name it
        explicitly via {!Poly} rather than [include]ing it. *)
    module Poly = Wire.Wrap.Proof_state

    (** Wire-form (out-of-circuit) instantiation. Pins the digest /
        bulletproof / branch_data slots; ['plonk] and ['fp] stay
        polymorphic. *)
    module Constant = struct
      type ('plonk, 'fp) t =
        { deferred_values : ('plonk, 'fp) Deferred_values.Constant.t
        ; sponge_digest_before_evaluations : Digest_.Constant.t
        ; messages_for_next_wrap_proof : Digest_.Constant.t
        }

      let to_stable
          ({ deferred_values
           ; sponge_digest_before_evaluations
           ; messages_for_next_wrap_proof
           } :
            ('plonk, 'fp) t ) :
          ( 'plonk
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , Digest_.Constant.t
          , Digest_.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Poly.Stable.V1.t =
        { deferred_values =
            Deferred_values.Constant.to_deferred_values deferred_values
        ; sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }

      let of_stable
          ({ deferred_values
           ; sponge_digest_before_evaluations
           ; messages_for_next_wrap_proof
           } :
            ( 'plonk
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , 'fp
            , Digest_.Constant.t
            , Digest_.Constant.t
            , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Branch_data.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp) t =
        { deferred_values =
            Deferred_values.Constant.of_deferred_values deferred_values
        ; sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }
    end

    let _ = fun (c : (_, _) Constant.t) -> Constant.of_stable (Constant.to_stable c)

    (** Step-circuit (Tick) instantiation. *)
    module Step = struct
      type ('plonk, 'fp) t =
        { deferred_values : ('plonk, 'fp) Deferred_values.Step.t
        ; sponge_digest_before_evaluations : Step_impl.Field.t
        ; messages_for_next_wrap_proof : Step_impl.Field.t
        }

      let to_stable
          ({ deferred_values
           ; sponge_digest_before_evaluations
           ; messages_for_next_wrap_proof
           } :
            ('plonk, 'fp) t ) :
          ( 'plonk
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp
          , Step_impl.Field.t
          , Step_impl.Field.t
          , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.Checked.Step.t )
          Poly.Stable.V1.t =
        { deferred_values =
            Deferred_values.Step.to_deferred_values deferred_values
        ; sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }

      let of_stable
          ({ deferred_values
           ; sponge_digest_before_evaluations
           ; messages_for_next_wrap_proof
           } :
            ( 'plonk
            , Step_impl.Field.t Scalar_challenge.t
            , 'fp
            , Step_impl.Field.t
            , Step_impl.Field.t
            , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Branch_data.Checked.Step.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp) t =
        { deferred_values =
            Deferred_values.Step.of_deferred_values deferred_values
        ; sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }
    end

    let _ = fun (s : (_, _) Step.t) -> Step.of_stable (Step.to_stable s)

    (** Wrap-circuit (Tock) instantiation. *)
    module Wrap = struct
      type ('plonk, 'fp) t =
        { deferred_values : ('plonk, 'fp) Deferred_values.Wrap.t
        ; sponge_digest_before_evaluations : Wrap_impl.Field.t
        ; messages_for_next_wrap_proof : Wrap_impl.Field.t
        }

      let to_stable
          ({ deferred_values
           ; sponge_digest_before_evaluations
           ; messages_for_next_wrap_proof
           } :
            ('plonk, 'fp) t ) :
          ( 'plonk
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp
          , Wrap_impl.Field.t
          , Wrap_impl.Field.t
          , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Wrap_impl.Field.t )
          Poly.Stable.V1.t =
        { deferred_values =
            Deferred_values.Wrap.to_deferred_values deferred_values
        ; sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }

      let of_stable
          ({ deferred_values
           ; sponge_digest_before_evaluations
           ; messages_for_next_wrap_proof
           } :
            ( 'plonk
            , Wrap_impl.Field.t Scalar_challenge.t
            , 'fp
            , Wrap_impl.Field.t
            , Wrap_impl.Field.t
            , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Wrap_impl.Field.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp) t =
        { deferred_values =
            Deferred_values.Wrap.of_deferred_values deferred_values
        ; sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }
    end

    let _ = fun (w : (_, _) Wrap.t) -> Wrap.of_stable (Wrap.to_stable w)
  end

  (** The component of the proof accumulation state that is only computed on by the
      "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
  module Messages_for_next_step_proof = struct
    type ('g, 's, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
      { app_state : 's
            (** The actual application-level state (e.g., for Mina, this is the protocol state which contains the
    merkle root of the ledger, state related to consensus, etc.) *)
      ; dlog_plonk_index : 'g Plonk_verification_key_evals.t
            (** The verification key corresponding to the wrap-circuit for this recursive proof system.
          It gets threaded through all the circuits so that the step circuits can verify proofs against
          it.
      *)
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }
    [@@deriving sexp]

    let to_field_elements (type g f)
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        } ~app_state:app_state_to_field_elements ~comm ~(g : g -> f list) =
      Array.concat
        [ index_to_field_elements ~g:comm dlog_plonk_index
        ; app_state_to_field_elements app_state
        ; Vector.map2 challenge_polynomial_commitments
            old_bulletproof_challenges ~f:(fun comm chals ->
              Array.append (Array.of_list (g comm)) (Vector.to_array chals) )
          |> Vector.to_list |> Array.concat
        ]

    let to_field_elements_without_index (type g f)
        { app_state
        ; dlog_plonk_index = _
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        } ~app_state:app_state_to_field_elements ~(g : g -> f list) =
      Array.concat
        [ app_state_to_field_elements app_state
        ; Vector.map2 challenge_polynomial_commitments
            old_bulletproof_challenges ~f:(fun comm chals ->
              Array.append (Array.of_list (g comm)) (Vector.to_array chals) )
          |> Vector.to_list |> Array.concat
        ]

    (* Alias for [t]; must be defined BEFORE the [open Snarky_backendless
       .H_list] below, because that open brings [H_list.t] (2-arg) into
       scope and shadows the parent [t]. *)
    type ('a, 'b, 'c, 'd) messages_for_next_step_proof_t = ('a, 'b, 'c, 'd) t

    open Snarky_backendless.H_list

    let[@warning "-45"] to_hlist
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        } =
      [ app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      ]

    let[@warning "-45"] of_hlist
        ([ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         ] :
          (unit, _) t ) =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }

    (** Wire-form (out-of-circuit) instantiation: the commitment slot ['g]
        is pinned to [Backend.Tock.Curve.Affine.t], while ['s] (app
        state), ['challenge_polynomial_commitments], and
        ['bulletproof_challenges] remain parametric. *)
    module Constant = struct
      type ('s, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
        { app_state : 's
        ; dlog_plonk_index :
            Backend.Tock.Curve.Affine.t Plonk_verification_key_evals.t
        ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
        ; old_bulletproof_challenges : 'bulletproof_challenges
        }

      let to_messages_for_next_step_proof_t
          ({ app_state
           ; dlog_plonk_index
           ; challenge_polynomial_commitments
           ; old_bulletproof_challenges
           } :
            ('s, 'cpc, 'bp) t ) :
          ( Backend.Tock.Curve.Affine.t
          , 's
          , 'cpc
          , 'bp )
          messages_for_next_step_proof_t =
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        }

      let of_messages_for_next_step_proof_t
          ({ app_state
           ; dlog_plonk_index
           ; challenge_polynomial_commitments
           ; old_bulletproof_challenges
           } :
            ( Backend.Tock.Curve.Affine.t
            , 's
            , 'cpc
            , 'bp )
            messages_for_next_step_proof_t ) : ('s, 'cpc, 'bp) t =
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        }
    end

    let _ = fun (c : (_, _, _) Constant.t) ->
      Constant.of_messages_for_next_step_proof_t
        (Constant.to_messages_for_next_step_proof_t c)

    (** Step-circuit (Tick) instantiation. *)
    module Step = struct
      type ('s, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
        { app_state : 's
        ; dlog_plonk_index :
            (Step_impl.Field.t * Step_impl.Field.t)
            Plonk_verification_key_evals.t
        ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
        ; old_bulletproof_challenges : 'bulletproof_challenges
        }

      let to_messages_for_next_step_proof_t
          ({ app_state
           ; dlog_plonk_index
           ; challenge_polynomial_commitments
           ; old_bulletproof_challenges
           } :
            ('s, 'cpc, 'bp) t ) :
          ( Step_impl.Field.t * Step_impl.Field.t
          , 's
          , 'cpc
          , 'bp )
          messages_for_next_step_proof_t =
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        }

      let of_messages_for_next_step_proof_t
          ({ app_state
           ; dlog_plonk_index
           ; challenge_polynomial_commitments
           ; old_bulletproof_challenges
           } :
            ( Step_impl.Field.t * Step_impl.Field.t
            , 's
            , 'cpc
            , 'bp )
            messages_for_next_step_proof_t ) : ('s, 'cpc, 'bp) t =
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        }
    end

    let _ = fun (s : (_, _, _) Step.t) ->
      Step.of_messages_for_next_step_proof_t
        (Step.to_messages_for_next_step_proof_t s)

    (** Wrap-circuit (Tock) instantiation. *)
    module Wrap = struct
      type ('s, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
        { app_state : 's
        ; dlog_plonk_index :
            (Wrap_impl.Field.t * Wrap_impl.Field.t)
            Plonk_verification_key_evals.t
        ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
        ; old_bulletproof_challenges : 'bulletproof_challenges
        }

      let to_messages_for_next_step_proof_t
          ({ app_state
           ; dlog_plonk_index
           ; challenge_polynomial_commitments
           ; old_bulletproof_challenges
           } :
            ('s, 'cpc, 'bp) t ) :
          ( Wrap_impl.Field.t * Wrap_impl.Field.t
          , 's
          , 'cpc
          , 'bp )
          messages_for_next_step_proof_t =
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        }

      let of_messages_for_next_step_proof_t
          ({ app_state
           ; dlog_plonk_index
           ; challenge_polynomial_commitments
           ; old_bulletproof_challenges
           } :
            ( Wrap_impl.Field.t * Wrap_impl.Field.t
            , 's
            , 'cpc
            , 'bp )
            messages_for_next_step_proof_t ) : ('s, 'cpc, 'bp) t =
        { app_state
        ; dlog_plonk_index
        ; challenge_polynomial_commitments
        ; old_bulletproof_challenges
        }
    end

    let _ = fun (w : (_, _, _) Wrap.t) ->
      Wrap.of_messages_for_next_step_proof_t
        (Wrap.to_messages_for_next_step_proof_t w)
  end

  module Lookup_parameters = struct
    (* Values needed for computing lookup parts of the verifier circuit. *)
    type ('chal, 'chal_var, 'fp, 'fp_var) t =
      { zero : ('chal, 'chal_var, 'fp, 'fp_var) Zero_values.t
      ; use : Opt.Flag.t
      }

    let opt_spec { zero = { value; var }; use } =
      Spec.T.Opt
        { inner = Struct [ Scalar Challenge ]
        ; flag = use
        ; dummy1 =
            [ Kimchi_backend_common.Scalar_challenge.create value.challenge ]
        ; dummy2 =
            [ Kimchi_backend_common.Scalar_challenge.create var.challenge ]
        }
  end

  (** This is the full statement for "wrap" proofs which contains
      - the application-level statement (app_state)
      - data needed to perform the final verification of the proof, which correspond
        to parts of incompletely verified proofs.
  *)
  module Statement = struct
    include Wire.Wrap.Statement

    module Minimal = struct
      include Wire.Wrap.Statement.Minimal
    end

    module In_circuit = struct
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fp_opt
           , 'lookup_opt
           , 'bool
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'messages_for_next_step_proof
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'fp_opt
          , 'lookup_opt
          , 'bool )
          Proof_state.Deferred_values.Plonk.In_circuit.t
        , 'scalar_challenge
        , 'fp
        , 'messages_for_next_wrap_proof
        , 'digest
        , 'messages_for_next_step_proof
        , 'bp_chals
        , 'index )
        Stable.Latest.t
      [@@deriving compare, yojson, sexp, hash, equal]

      (** A layout of the raw data in a statement, which is needed for
          representing it inside the circuit. *)
      let spec _impl lookup feature_flags =
        let feature_flags_spec =
          let [ f1; f2; f3; f4; f5; f6; f7; f8 ] =
            (* Ensure that layout is the same *)
            Plonk_types.Features.to_data feature_flags
          in
          let constant x =
            Spec.T.Constant (x, (fun x y -> assert (Bool.equal x y)), B Bool)
          in
          let maybe_constant flag =
            match flag with
            | Opt.Flag.Yes ->
                constant true
            | Opt.Flag.No ->
                constant false
            | Opt.Flag.Maybe ->
                Spec.T.B Bool
          in
          Spec.T.Struct
            [ maybe_constant f1
            ; maybe_constant f2
            ; maybe_constant f3
            ; maybe_constant f4
            ; maybe_constant f5
            ; maybe_constant f6
            ; maybe_constant f7
            ; maybe_constant f8
            ]
        in
        Spec.T.Struct
          [ Vector (B Field, Nat.N5.n)
          ; Vector (B Challenge, Nat.N2.n)
          ; Vector (Scalar Challenge, Nat.N3.n)
          ; Vector (B Digest, Nat.N3.n)
          ; Vector (B Bulletproof_challenge, Backend.Tick.Rounds.n)
          ; Vector (B Branch_data, Nat.N1.n)
          ; feature_flags_spec
          ; Lookup_parameters.opt_spec lookup
          ]

      (** Convert a statement (as structured data) into the flat data-based representation. *)
      let[@warning "-45"] to_data
          ({ proof_state =
               { deferred_values =
                   { xi
                   ; combined_inner_product
                   ; b
                   ; branch_data
                   ; bulletproof_challenges
                   ; plonk =
                       { alpha
                       ; beta
                       ; gamma
                       ; zeta
                       ; zeta_to_srs_length
                       ; zeta_to_domain_size
                       ; perm
                       ; feature_flags
                       ; joint_combiner
                       }
                   }
               ; sponge_digest_before_evaluations
               ; messages_for_next_wrap_proof
                 (* messages_for_next_wrap_proof is represented as a digest (and then unhashed) inside the circuit *)
               }
           ; messages_for_next_step_proof
             (* messages_for_next_step_proof is represented as a digest inside the circuit *)
           } :
            _ t ) ~option_map =
        let open Vector in
        let fp =
          [ combined_inner_product
          ; b
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ]
        in
        let challenge = [ beta; gamma ] in
        let scalar_challenge = [ alpha; zeta; xi ] in
        let digest =
          [ sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          ; messages_for_next_step_proof
          ]
        in
        let index = [ branch_data ] in
        Hlist.HlistId.
          [ fp
          ; challenge
          ; scalar_challenge
          ; digest
          ; bulletproof_challenges
          ; index
          ; Plonk_types.Features.to_data feature_flags
          ; option_map joint_combiner ~f:(fun x -> Hlist.HlistId.[ x ])
          ]

      (** Construct a statement (as structured data) from the flat data-based representation. *)
      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ fp
            ; challenge
            ; scalar_challenge
            ; digest
            ; bulletproof_challenges
            ; index
            ; feature_flags
            ; joint_combiner
            ] ~option_map : _ t =
        let open Vector in
        let [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ] =
          fp
        in
        let [ beta; gamma ] = challenge in
        let [ alpha; zeta; xi ] = scalar_challenge in
        let [ sponge_digest_before_evaluations
            ; messages_for_next_wrap_proof
            ; messages_for_next_step_proof
            ] =
          digest
        in
        let [ branch_data ] = index in
        let feature_flags = Plonk_types.Features.of_data feature_flags in
        { proof_state =
            { deferred_values =
                { xi
                ; combined_inner_product
                ; b
                ; branch_data
                ; bulletproof_challenges
                ; plonk =
                    { alpha
                    ; beta
                    ; gamma
                    ; zeta
                    ; zeta_to_srs_length
                    ; zeta_to_domain_size
                    ; perm
                    ; feature_flags
                    ; joint_combiner =
                        option_map joint_combiner ~f:(fun Hlist.HlistId.[ x ] ->
                            x )
                    }
                }
            ; sponge_digest_before_evaluations
            ; messages_for_next_wrap_proof
            }
        ; messages_for_next_step_proof
        }
    end

    let to_minimal
        ({ proof_state; messages_for_next_step_proof } : _ In_circuit.t)
        ~to_option : _ Minimal.t =
      { proof_state = Proof_state.to_minimal ~to_option proof_state
      ; messages_for_next_step_proof
      }

    (** Wire-format polymorphic skeleton. Concrete records below name it
        explicitly via {!Poly} rather than [include]ing it. *)
    module Poly = Wire.Wrap.Statement

    (** Wire-form (out-of-circuit) instantiation. Pins
        [messages_for_next_step_proof] to a digest; ['plonk] and ['fp]
        stay polymorphic. *)
    module Constant = struct
      type ('plonk, 'fp) t =
        { proof_state : ('plonk, 'fp) Proof_state.Constant.t
        ; messages_for_next_step_proof : Digest_.Constant.t
        }

      let to_stable
          ({ proof_state; messages_for_next_step_proof } : ('plonk, 'fp) t) :
          ( 'plonk
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , Digest_.Constant.t
          , Digest_.Constant.t
          , Digest_.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Poly.Stable.V1.t =
        { proof_state = Proof_state.Constant.to_stable proof_state
        ; messages_for_next_step_proof
        }

      let of_stable
          ({ proof_state; messages_for_next_step_proof } :
            ( 'plonk
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , 'fp
            , Digest_.Constant.t
            , Digest_.Constant.t
            , Digest_.Constant.t
            , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Branch_data.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp) t =
        { proof_state = Proof_state.Constant.of_stable proof_state
        ; messages_for_next_step_proof
        }
    end

    let _ = fun (c : (_, _) Constant.t) -> Constant.of_stable (Constant.to_stable c)

    (** Step-circuit (Tick) instantiation. *)
    module Step = struct
      type ('plonk, 'fp, 'messages_for_next_step_proof) t =
        { proof_state : ('plonk, 'fp) Proof_state.Step.t
        ; messages_for_next_step_proof : 'messages_for_next_step_proof
        }

      let to_stable
          ({ proof_state; messages_for_next_step_proof } :
            ('plonk, 'fp, 'm) t ) :
          ( 'plonk
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp
          , Step_impl.Field.t
          , Step_impl.Field.t
          , 'm
          , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.Checked.Step.t )
          Poly.Stable.V1.t =
        { proof_state = Proof_state.Step.to_stable proof_state
        ; messages_for_next_step_proof
        }

      let of_stable
          ({ proof_state; messages_for_next_step_proof } :
            ( 'plonk
            , Step_impl.Field.t Scalar_challenge.t
            , 'fp
            , Step_impl.Field.t
            , Step_impl.Field.t
            , 'm
            , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Branch_data.Checked.Step.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp, 'm) t =
        { proof_state = Proof_state.Step.of_stable proof_state
        ; messages_for_next_step_proof
        }
    end

    let _ = fun (s : (_, _, _) Step.t) -> Step.of_stable (Step.to_stable s)

    (** Wrap-circuit (Tock) instantiation. *)
    module Wrap = struct
      type ('plonk, 'fp, 'messages_for_next_step_proof) t =
        { proof_state : ('plonk, 'fp) Proof_state.Wrap.t
        ; messages_for_next_step_proof : 'messages_for_next_step_proof
        }

      let to_stable
          ({ proof_state; messages_for_next_step_proof } :
            ('plonk, 'fp, 'm) t ) :
          ( 'plonk
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp
          , Wrap_impl.Field.t
          , Wrap_impl.Field.t
          , 'm
          , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Wrap_impl.Field.t )
          Poly.Stable.V1.t =
        { proof_state = Proof_state.Wrap.to_stable proof_state
        ; messages_for_next_step_proof
        }

      let of_stable
          ({ proof_state; messages_for_next_step_proof } :
            ( 'plonk
            , Wrap_impl.Field.t Scalar_challenge.t
            , 'fp
            , Wrap_impl.Field.t
            , Wrap_impl.Field.t
            , 'm
            , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Wrap_impl.Field.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp, 'm) t =
        { proof_state = Proof_state.Wrap.of_stable proof_state
        ; messages_for_next_step_proof
        }
    end

    let _ = fun (w : (_, _, _) Wrap.t) -> Wrap.of_stable (Wrap.to_stable w)
  end
end

module Step = struct
  module Plonk_polys = Nat.N10

  module Bulletproof = struct
    include Plonk_types.Openings.Bulletproof

    module Advice = struct
      (** This is data that can be computed in linear time from the proof + statement.

          It doesn't need to be sent on the wire, but it does need to be provided to the verifier
      *)
      type 'fq t =
        { b : 'fq
        ; combined_inner_product : 'fq (* sum_i r^i sum_j xi^j f_j(pt_i) *)
        }
      [@@deriving hlist]
    end
  end

  module Proof_state = struct
    module Deferred_values = struct
      module Plonk = Step_plonk_iop

      (** All the scalar-field values needed to finalize the verification of a proof
    by checking that the correct values were used in the "group operations" part of the
    verifier.

    Consists of some evaluations of PLONK polynomials (columns, permutation aggregation, etc.)
    and the remainder are things related to the inner product argument.
*)
      type ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_ =
        { plonk : 'plonk
        ; combined_inner_product : 'fq
              (** combined_inner_product = sum_{i < num_evaluation_points} sum_{j < num_polys} r^i xi^j f_j(pt_i) *)
        ; xi : 'scalar_challenge
              (** The challenge used for combining polynomials *)
        ; bulletproof_challenges : 'bulletproof_challenges
              (** The challenges from the inner-product argument that was partially verified. *)
        ; b : 'fq
              (** b = challenge_poly plonk.zeta + r * challenge_poly (domain_generrator * plonk.zeta)
                where challenge_poly(x) = \prod_i (1 + bulletproof_challenges.(i) * x^{2^{k - 1 - i}})
            *)
        }
      [@@deriving sexp, compare, yojson]

      module Minimal = struct
        type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
          ( ('challenge, 'scalar_challenge) Plonk.Minimal.Poly.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges )
          t_
        [@@deriving sexp, compare, yojson]
      end

      module In_circuit = struct
        type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
          ( ('challenge, 'scalar_challenge, 'fq) Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges )
          t_
        [@@deriving sexp, compare, yojson]
      end

      (** Wire-form (out-of-circuit) instantiation of {!t_}; ['plonk] and
          ['fq] are left polymorphic because callers pick from the
          Minimal/In_circuit Plonk submodules and between Type1/Type2
          Shifted_value forms. {!to_t_} / {!of_t_} bridge to the polymorphic
          skeleton. *)
      module Constant = struct
        type ('plonk, 'fq) t =
          { plonk : 'plonk
          ; combined_inner_product : 'fq
          ; xi : Limb_vector.Challenge.Constant.t Scalar_challenge.t
          ; bulletproof_challenges :
              ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t
          ; b : 'fq
          }

        let to_t_
            ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
              ('plonk, 'fq) t ) :
            ( 'plonk
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , 'fq
            , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t )
            t_ =
          { plonk; combined_inner_product; xi; bulletproof_challenges; b }

        let of_t_
            ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
              ( 'plonk
              , Limb_vector.Challenge.Constant.t Scalar_challenge.t
              , 'fq
              , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                  Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t )
              t_ ) : ('plonk, 'fq) t =
          { plonk; combined_inner_product; xi; bulletproof_challenges; b }
      end

      let _ = fun (c : (_, _) Constant.t) -> Constant.of_t_ (Constant.to_t_ c)

      (** Step-circuit (Tick) instantiation of {!t_}. *)
      module Step = struct
        type ('plonk, 'fq) t =
          { plonk : 'plonk
          ; combined_inner_product : 'fq
          ; xi : Step_impl.Field.t Scalar_challenge.t
          ; bulletproof_challenges :
              ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t
          ; b : 'fq
          }

        let to_t_
            ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
              ('plonk, 'fq) t ) :
            ( 'plonk
            , Step_impl.Field.t Scalar_challenge.t
            , 'fq
            , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t )
            t_ =
          { plonk; combined_inner_product; xi; bulletproof_challenges; b }

        let of_t_
            ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
              ( 'plonk
              , Step_impl.Field.t Scalar_challenge.t
              , 'fq
              , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t )
              t_ ) : ('plonk, 'fq) t =
          { plonk; combined_inner_product; xi; bulletproof_challenges; b }
      end

      let _ = fun (s : (_, _) Step.t) -> Step.of_t_ (Step.to_t_ s)

      (** Wrap-circuit (Tock) instantiation of {!t_}. *)
      module Wrap = struct
        type ('plonk, 'fq) t =
          { plonk : 'plonk
          ; combined_inner_product : 'fq
          ; xi : Wrap_impl.Field.t Scalar_challenge.t
          ; bulletproof_challenges :
              ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t
          ; b : 'fq
          }

        let to_t_
            ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
              ('plonk, 'fq) t ) :
            ( 'plonk
            , Wrap_impl.Field.t Scalar_challenge.t
            , 'fq
            , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t )
            t_ =
          { plonk; combined_inner_product; xi; bulletproof_challenges; b }

        let of_t_
            ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
              ( 'plonk
              , Wrap_impl.Field.t Scalar_challenge.t
              , 'fq
              , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t )
              t_ ) : ('plonk, 'fq) t =
          { plonk; combined_inner_product; xi; bulletproof_challenges; b }
      end

      let _ = fun (w : (_, _) Wrap.t) -> Wrap.of_t_ (Wrap.to_t_ w)
    end

    module Messages_for_next_wrap_proof =
      Wrap.Proof_state.Messages_for_next_wrap_proof
    module Messages_for_next_step_proof = Wrap.Messages_for_next_step_proof

    module Per_proof = struct
      (** For each proof that a step circuit verifies, we do not verify the whole proof.
          Specifically,
          - we defer calculations involving the "other field" (i.e., the scalar-field of the group
            elements involved in the proof.
          - we do not fully verify the inner-product argument as that would be O(n) and instead
            do the accumulator trick.

          As a result, for each proof that a step circuit verifies, we must expose some data
          related to it as part of the step circuit's statement, in order to allow those proofs
          to be fully verified eventually.

          This is that data. *)
      type ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_ =
        { deferred_values :
            ( 'plonk
            , 'scalar_challenge
            , 'fq
            , 'bulletproof_challenges )
            Deferred_values.t_
              (** Scalar values related to the proof *)
        ; should_finalize : 'bool
              (** We allow circuits in pickles proof systems to decide if it's OK that a proof did
    not recursively verify. In that case, when we expose the unfinalized bits, we need
    to communicate that it's OK if those bits do not "finalize". That's what this boolean
    is for. *)
        ; sponge_digest_before_evaluations : 'digest
        }
      [@@deriving sexp, compare, yojson]

      module Minimal = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t =
          ( ('challenge, 'scalar_challenge) Deferred_values.Plonk.Minimal.Poly.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges
          , 'digest
          , 'bool )
          t_
        [@@deriving sexp, compare, yojson]
      end

      module In_circuit = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fq )
            Deferred_values.Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges
          , 'digest
          , 'bool )
          t_
        [@@deriving sexp, compare, yojson]

        (** A layout of the raw data in this value, which is needed for
          representing it inside the circuit. *)
        let spec bp_log2 =
          Spec.T.Struct
            [ Vector (B Field, Nat.N5.n)
            ; Vector (B Digest, Nat.N1.n)
            ; Vector (B Challenge, Nat.N2.n)
            ; Vector (Scalar Challenge, Nat.N3.n)
            ; Vector (B Bulletproof_challenge, bp_log2)
            ; Vector (B Bool, Nat.N1.n)
            ]

        let[@warning "-45"] to_data
            ({ deferred_values =
                 { xi
                 ; bulletproof_challenges
                 ; b
                 ; combined_inner_product
                 ; plonk =
                     { alpha
                     ; beta
                     ; gamma
                     ; zeta
                     ; zeta_to_srs_length
                     ; zeta_to_domain_size
                     ; perm
                     }
                 }
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              _ t ) =
          let open Vector in
          let fq =
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
          in
          let challenge = [ beta; gamma ] in
          let scalar_challenge = [ alpha; zeta; xi ] in
          let digest = [ sponge_digest_before_evaluations ] in
          let bool = [ should_finalize ] in
          let open Hlist.HlistId in
          [ fq
          ; digest
          ; challenge
          ; scalar_challenge
          ; bulletproof_challenges
          ; bool
          ]

        let[@warning "-45"] of_data
            Hlist.HlistId.
              [ Vector.
                  [ combined_inner_product
                  ; b
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ]
              ; Vector.[ sponge_digest_before_evaluations ]
              ; Vector.[ beta; gamma ]
              ; Vector.[ alpha; zeta; xi ]
              ; bulletproof_challenges
              ; Vector.[ should_finalize ]
              ] : _ t =
          { deferred_values =
              { xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  }
              }
          ; should_finalize
          ; sponge_digest_before_evaluations
          }
      end

      let typ fq ~assert_16_bits =
        let open In_circuit in
        Spec.typ fq ~assert_16_bits (spec Backend.Tock.Rounds.n)
        |> Step_impl.Typ.transport ~there:to_data ~back:of_data
        |> Step_impl.Typ.transport_var ~there:to_data ~back:of_data

      let wrap_typ fq ~assert_16_bits =
        let open In_circuit in
        Spec.wrap_typ fq ~assert_16_bits (spec Backend.Tock.Rounds.n)
        |> Wrap_impl.Typ.transport ~there:to_data ~back:of_data
        |> Wrap_impl.Typ.transport_var ~there:to_data ~back:of_data

      (** Wire-form (out-of-circuit) instantiation of {!t_}; the
          [deferred_values] slot is also out-of-circuit
          ({!Deferred_values.Constant.t}). {!to_t_} / {!of_t_} bridge
          to the polymorphic skeleton. *)
      module Constant = struct
        type ('plonk, 'fq, 'digest) t =
          { deferred_values : ('plonk, 'fq) Deferred_values.Constant.t
          ; should_finalize : bool
          ; sponge_digest_before_evaluations : 'digest
          }

        let to_t_
            ({ deferred_values
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              ('plonk, 'fq, 'digest) t ) :
            ( 'plonk
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , 'fq
            , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t
            , 'digest
            , bool )
            t_ =
          { deferred_values = Deferred_values.Constant.to_t_ deferred_values
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        let of_t_
            ({ deferred_values
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              ( 'plonk
              , Limb_vector.Challenge.Constant.t Scalar_challenge.t
              , 'fq
              , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                  Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t
              , 'digest
              , bool )
              t_ ) : ('plonk, 'fq, 'digest) t =
          { deferred_values = Deferred_values.Constant.of_t_ deferred_values
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        (* [spec] / [to_data] / [of_data] for the value side: outer
           [Per_proof.Constant.t] with the inner Plonk pinned to
           [Plonk.In_circuit.Constant.t]. *)
        let spec bp_log2 = In_circuit.spec bp_log2

        let[@warning "-45"] to_data
            (t :
              ( 'fp Deferred_values.Plonk.In_circuit.Constant.t
              , 'fq
              , 'digest )
              t ) =
          let { deferred_values
              ; should_finalize
              ; sponge_digest_before_evaluations
              } =
            t
          in
          let { Deferred_values.Constant.xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk
              } =
            deferred_values
          in
          let ({ alpha
               ; beta
               ; gamma
               ; zeta
               ; zeta_to_srs_length
               ; zeta_to_domain_size
               ; perm
               }
                : _ Deferred_values.Plonk.In_circuit.Constant.t ) =
            plonk
          in
          let open Vector in
          let fq =
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
          in
          let challenge = [ beta; gamma ] in
          let scalar_challenge = [ alpha; zeta; xi ] in
          let digest = [ sponge_digest_before_evaluations ] in
          let bool = [ should_finalize ] in
          let open Hlist.HlistId in
          [ fq
          ; digest
          ; challenge
          ; scalar_challenge
          ; bulletproof_challenges
          ; bool
          ]

        let[@warning "-45"] of_data
            Hlist.HlistId.
              [ Vector.
                  [ combined_inner_product
                  ; b
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ]
              ; Vector.[ sponge_digest_before_evaluations ]
              ; Vector.[ beta; gamma ]
              ; Vector.[ alpha; zeta; xi ]
              ; bulletproof_challenges
              ; Vector.[ should_finalize ]
              ] :
            ( 'fp Deferred_values.Plonk.In_circuit.Constant.t
            , 'fq
            , 'digest )
            t =
          { deferred_values =
              { xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  }
              }
          ; should_finalize
          ; sponge_digest_before_evaluations
          }
      end

      let _ = fun (c : (_, _, _) Constant.t) -> Constant.of_t_ (Constant.to_t_ c)

      (** Step-circuit (Tick) instantiation of {!t_}. *)
      module Step = struct
        type ('plonk, 'fq, 'digest, 'bool) t =
          { deferred_values : ('plonk, 'fq) Deferred_values.Step.t
          ; should_finalize : 'bool
          ; sponge_digest_before_evaluations : 'digest
          }

        let to_t_
            ({ deferred_values
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              ('plonk, 'fq, 'digest, 'bool) t ) :
            ( 'plonk
            , Step_impl.Field.t Scalar_challenge.t
            , 'fq
            , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t
            , 'digest
            , 'bool )
            t_ =
          { deferred_values = Deferred_values.Step.to_t_ deferred_values
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        let of_t_
            ({ deferred_values
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              ( 'plonk
              , Step_impl.Field.t Scalar_challenge.t
              , 'fq
              , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t
              , 'digest
              , 'bool )
              t_ ) : ('plonk, 'fq, 'digest, 'bool) t =
          { deferred_values = Deferred_values.Step.of_t_ deferred_values
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        let spec bp_log2 = In_circuit.spec bp_log2

        let[@warning "-45"] to_data
            (t :
              ( 'fp Deferred_values.Plonk.In_circuit.Step.t
              , 'fq
              , 'digest
              , 'bool )
              t ) =
          let { deferred_values
              ; should_finalize
              ; sponge_digest_before_evaluations
              } =
            t
          in
          let { Deferred_values.Step.xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk
              } =
            deferred_values
          in
          let ({ alpha
               ; beta
               ; gamma
               ; zeta
               ; zeta_to_srs_length
               ; zeta_to_domain_size
               ; perm
               }
                : _ Deferred_values.Plonk.In_circuit.Step.t ) =
            plonk
          in
          let open Vector in
          let fq =
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
          in
          let challenge = [ beta; gamma ] in
          let scalar_challenge = [ alpha; zeta; xi ] in
          let digest = [ sponge_digest_before_evaluations ] in
          let bool = [ should_finalize ] in
          let open Hlist.HlistId in
          [ fq
          ; digest
          ; challenge
          ; scalar_challenge
          ; bulletproof_challenges
          ; bool
          ]

        let[@warning "-45"] of_data
            Hlist.HlistId.
              [ Vector.
                  [ combined_inner_product
                  ; b
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ]
              ; Vector.[ sponge_digest_before_evaluations ]
              ; Vector.[ beta; gamma ]
              ; Vector.[ alpha; zeta; xi ]
              ; bulletproof_challenges
              ; Vector.[ should_finalize ]
              ] :
            ( 'fp Deferred_values.Plonk.In_circuit.Step.t
            , 'fq
            , 'digest
            , 'bool )
            t =
          { deferred_values =
              { xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  }
              }
          ; should_finalize
          ; sponge_digest_before_evaluations
          }
      end

      let _ = fun (s : (_, _, _, _) Step.t) -> Step.of_t_ (Step.to_t_ s)

      (** Wrap-circuit (Tock) instantiation of {!t_}. *)
      module Wrap = struct
        type ('plonk, 'fq, 'digest, 'bool) t =
          { deferred_values : ('plonk, 'fq) Deferred_values.Wrap.t
          ; should_finalize : 'bool
          ; sponge_digest_before_evaluations : 'digest
          }

        let to_t_
            ({ deferred_values
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              ('plonk, 'fq, 'digest, 'bool) t ) :
            ( 'plonk
            , Wrap_impl.Field.t Scalar_challenge.t
            , 'fq
            , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tock.Rounds.n )
              Vector.t
            , 'digest
            , 'bool )
            t_ =
          { deferred_values = Deferred_values.Wrap.to_t_ deferred_values
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        let of_t_
            ({ deferred_values
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              ( 'plonk
              , Wrap_impl.Field.t Scalar_challenge.t
              , 'fq
              , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t
              , 'digest
              , 'bool )
              t_ ) : ('plonk, 'fq, 'digest, 'bool) t =
          { deferred_values = Deferred_values.Wrap.of_t_ deferred_values
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        let spec bp_log2 = In_circuit.spec bp_log2

        let[@warning "-45"] to_data
            (t :
              ( 'fp Deferred_values.Plonk.In_circuit.Wrap.t
              , 'fq
              , 'digest
              , 'bool )
              t ) =
          let { deferred_values
              ; should_finalize
              ; sponge_digest_before_evaluations
              } =
            t
          in
          let { Deferred_values.Wrap.xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk
              } =
            deferred_values
          in
          let ({ alpha
               ; beta
               ; gamma
               ; zeta
               ; zeta_to_srs_length
               ; zeta_to_domain_size
               ; perm
               }
                : _ Deferred_values.Plonk.In_circuit.Wrap.t ) =
            plonk
          in
          let open Vector in
          let fq =
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
          in
          let challenge = [ beta; gamma ] in
          let scalar_challenge = [ alpha; zeta; xi ] in
          let digest = [ sponge_digest_before_evaluations ] in
          let bool = [ should_finalize ] in
          let open Hlist.HlistId in
          [ fq
          ; digest
          ; challenge
          ; scalar_challenge
          ; bulletproof_challenges
          ; bool
          ]

        let[@warning "-45"] of_data
            Hlist.HlistId.
              [ Vector.
                  [ combined_inner_product
                  ; b
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ]
              ; Vector.[ sponge_digest_before_evaluations ]
              ; Vector.[ beta; gamma ]
              ; Vector.[ alpha; zeta; xi ]
              ; bulletproof_challenges
              ; Vector.[ should_finalize ]
              ] :
            ( 'fp Deferred_values.Plonk.In_circuit.Wrap.t
            , 'fq
            , 'digest
            , 'bool )
            t =
          { deferred_values =
              { xi
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  }
              }
          ; should_finalize
          ; sponge_digest_before_evaluations
          }
      end

      let _ = fun (w : (_, _, _, _) Wrap.t) -> Wrap.of_t_ (Wrap.to_t_ w)
    end

    type ('unfinalized_proofs, 'messages_for_next_step_proof) t =
      { unfinalized_proofs : 'unfinalized_proofs
            (** A vector of the "per-proof" structures defined above, one for each proof
    that the step-circuit partially verifies. *)
      ; messages_for_next_step_proof : 'messages_for_next_step_proof
            (** The component of the proof accumulation state that is only computed on by the
          "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
      }
    [@@deriving sexp, compare, yojson, hlist]

    let spec unfinalized_proofs messages_for_next_step_proof =
      Spec.T.Struct [ unfinalized_proofs; messages_for_next_step_proof ]

    let[@warning "-60"] wrap_typ (type n) ~assert_16_bits
        (proofs_verified : (Opt.Flag.t Plonk_types.Features.t, n) Vector.t) fq :
        (((_, _) Vector.t, _) t, ((_, _) Vector.t, _) t) Wrap_impl.Typ.t =
      let per_proof _ = Per_proof.wrap_typ fq ~assert_16_bits in
      let unfinalized_proofs =
        Vector.wrap_typ' (Vector.map proofs_verified ~f:per_proof)
      in
      let messages_for_next_step_proof =
        Spec.wrap_typ fq ~assert_16_bits (B Spec.Digest)
      in
      Wrap_impl.Typ.of_hlistable
        [ unfinalized_proofs; messages_for_next_step_proof ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Statement = struct
    type ( 'unfinalized_proofs
         , 'messages_for_next_step_proof
         , 'messages_for_next_wrap_proof )
         t =
      { proof_state :
          ('unfinalized_proofs, 'messages_for_next_step_proof) Proof_state.t
      ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
            (** The component of the proof accumulation state that is only computed on by the
        "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
      }
    [@@deriving sexp, compare, yojson]

    let[@warning "-45"] to_data
        { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
        ; messages_for_next_wrap_proof
        } =
      let open Hlist.HlistId in
      [ Vector.map unfinalized_proofs
          ~f:Proof_state.Per_proof.In_circuit.to_data
      ; messages_for_next_step_proof
      ; messages_for_next_wrap_proof
      ]

    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ unfinalized_proofs
          ; messages_for_next_step_proof
          ; messages_for_next_wrap_proof
          ] =
      { proof_state =
          { unfinalized_proofs =
              Vector.map unfinalized_proofs
                ~f:Proof_state.Per_proof.In_circuit.of_data
          ; messages_for_next_step_proof
          }
      ; messages_for_next_wrap_proof
      }

    let spec proofs_verified bp_log2 =
      let per_proof = Proof_state.Per_proof.In_circuit.spec bp_log2 in
      Spec.T.Struct
        [ Vector (per_proof, proofs_verified)
        ; B Digest
        ; Vector (B Digest, proofs_verified)
        ]

    (** [to_data] / [of_data] / [spec] for the fresh
        [{Constant,Step,Wrap}.t] outer Statements. The flat-data output
        matches the toplevel [Step.Statement.{to_data, of_data, spec}],
        so [Spec]-driven typ construction stays interoperable. *)
    module Constant = struct
      let[@warning "-45"] to_data
          { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
          ; messages_for_next_wrap_proof
          } =
        let open Hlist.HlistId in
        [ Vector.map unfinalized_proofs
            ~f:Proof_state.Per_proof.Constant.to_data
        ; messages_for_next_step_proof
        ; messages_for_next_wrap_proof
        ]

      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ unfinalized_proofs
            ; messages_for_next_step_proof
            ; messages_for_next_wrap_proof
            ] =
        { proof_state =
            { unfinalized_proofs =
                Vector.map unfinalized_proofs
                  ~f:Proof_state.Per_proof.Constant.of_data
            ; messages_for_next_step_proof
            }
        ; messages_for_next_wrap_proof
        }

      let spec proofs_verified bp_log2 =
        let per_proof = Proof_state.Per_proof.Constant.spec bp_log2 in
        Spec.T.Struct
          [ Vector (per_proof, proofs_verified)
          ; B Digest
          ; Vector (B Digest, proofs_verified)
          ]
    end

    let _ : _ = (Constant.to_data, Constant.of_data, Constant.spec)

    module Step = struct
      let[@warning "-45"] to_data
          { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
          ; messages_for_next_wrap_proof
          } =
        let open Hlist.HlistId in
        [ Vector.map unfinalized_proofs ~f:Proof_state.Per_proof.Step.to_data
        ; messages_for_next_step_proof
        ; messages_for_next_wrap_proof
        ]

      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ unfinalized_proofs
            ; messages_for_next_step_proof
            ; messages_for_next_wrap_proof
            ] =
        { proof_state =
            { unfinalized_proofs =
                Vector.map unfinalized_proofs
                  ~f:Proof_state.Per_proof.Step.of_data
            ; messages_for_next_step_proof
            }
        ; messages_for_next_wrap_proof
        }

      let spec proofs_verified bp_log2 =
        let per_proof = Proof_state.Per_proof.Step.spec bp_log2 in
        Spec.T.Struct
          [ Vector (per_proof, proofs_verified)
          ; B Digest
          ; Vector (B Digest, proofs_verified)
          ]
    end

    let _ : _ = (Step.to_data, Step.of_data, Step.spec)

    module Wrap = struct
      let[@warning "-45"] to_data
          { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
          ; messages_for_next_wrap_proof
          } =
        let open Hlist.HlistId in
        [ Vector.map unfinalized_proofs ~f:Proof_state.Per_proof.Wrap.to_data
        ; messages_for_next_step_proof
        ; messages_for_next_wrap_proof
        ]

      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ unfinalized_proofs
            ; messages_for_next_step_proof
            ; messages_for_next_wrap_proof
            ] =
        { proof_state =
            { unfinalized_proofs =
                Vector.map unfinalized_proofs
                  ~f:Proof_state.Per_proof.Wrap.of_data
            ; messages_for_next_step_proof
            }
        ; messages_for_next_wrap_proof
        }

      let spec proofs_verified bp_log2 =
        let per_proof = Proof_state.Per_proof.Wrap.spec bp_log2 in
        Spec.T.Struct
          [ Vector (per_proof, proofs_verified)
          ; B Digest
          ; Vector (B Digest, proofs_verified)
          ]
    end

    let _ : _ = (Wrap.to_data, Wrap.of_data, Wrap.spec)
  end
end

module Nvector = Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector

module Challenges_vector = struct
  type 'n t = (Wrap_impl.Field.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Wrap_impl.Field.Constant.t Wrap_bp_vec.t, 'n) Vector.t
  end
end

(** Concrete (non-versioned) records mirroring
    [Pickles.Reduced_messages_for_next_proof_over_same_field].

    The versioned/[bin_io] type lives in
    [src/lib/crypto/pickles/reduced_messages_for_next_proof_over_same_field.ml].
    The records here are constrained equal to the corresponding
    [Mina_wire_types] skeleton so values flow freely between the two
    modules without conversion.

    Defining these records inside [Composition_types] lets consumers
    inline the [Step] / [Wrap] shapes directly instead of re-spelling
    them at every site. *)
module Reduced_messages_for_next = struct
  module Step = struct
    type ( 'app_state
         , 'challenge_polynomial_commitments
         , 'bulletproof_challenges )
         t =
          ( 'app_state
          , 'challenge_polynomial_commitments
          , 'bulletproof_challenges )
          Mina_wire_types.Pickles_reduced_messages_for_next_proof_over_same_field
          .Step
          .V1
          .t =
      { app_state : 'app_state
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    (** 3-parameter specialisation: the [challenge_polynomial_commitments]
        and [old_bulletproof_challenges] vector shapes are pinned to the
        forms that all step / wrap consumers actually use. *)
    module Specialised = struct
      type ('app_state, 'actual_proofs_verified, 'bp_chal_length) t =
        ( 'app_state
        , (Backend.Tock.Curve.Affine.t, 'actual_proofs_verified) Vector.t
        , ( ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , 'bp_chal_length )
            Vector.t
          , 'actual_proofs_verified )
          Vector.t )
        Mina_wire_types.Pickles_reduced_messages_for_next_proof_over_same_field
        .Step
        .V1
        .t
    end
  end

  module Wrap = struct
    module Challenges_vector = struct
      type t =
        Limb_vector.Challenge.Constant.t Scalar_challenge.t
        Bulletproof_challenge.t
        Wrap_bp_vec.t
    end

    type 'max_local_max_proofs_verified t =
      ( Backend.Tick.Curve.Affine.t
      , (Challenges_vector.t, 'max_local_max_proofs_verified) Vector.t )
      Wrap.Proof_state.Messages_for_next_wrap_proof.Poly.t
  end
end
