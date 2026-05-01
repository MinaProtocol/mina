open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Opt
module Wire = Wire
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

    module Deferred_values = struct
      (** All the deferred values needed, comprising values from the PLONK IOP
          verification, values from the inner-product argument, and
          [which_branch] which is needed to know the proper domain to use. *)
      include Wire.Wrap.Proof_state.Deferred_values

      module Plonk = struct
        module Minimal = struct
          (** Challenges from the PLONK IOP. These, plus the evaluations that are already in the proof, are
              all that's needed to derive all the values in the [In_circuit] version below.

              See src/lib/pickles/plonk_checks/plonk_checks.ml for the computation of the [In_circuit] value
              from the [Minimal] value.
          *)
          include Wire.Wrap.Proof_state.Deferred_values.Plonk.Minimal

          (** Wire-format polymorphic skeleton. Concrete records below name it
              explicitly via {!Poly} rather than [include]ing it. *)
          module Poly = Wire.Wrap.Proof_state.Deferred_values.Plonk.Minimal

          (** Wire-form (out-of-circuit) instantiation. {!to_stable} /
              {!of_stable} bridge to the [Mina_wire_types]-constrained
              polymorphic skeleton in {!Stable.V1.t}. *)
          module Constant = struct
            type t =
              { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
              ; beta : Limb_vector.Challenge.Constant.t
              ; gamma : Limb_vector.Challenge.Constant.t
              ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
              ; joint_combiner :
                  Limb_vector.Challenge.Constant.t Scalar_challenge.t option
              ; feature_flags : bool Plonk_types.Features.t
              }
            [@@deriving sexp, compare, yojson, hlist, hash, equal]

            let to_stable
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  t ) :
                ( Limb_vector.Challenge.Constant.t
                , Limb_vector.Challenge.Constant.t Scalar_challenge.t
                , bool )
                Poly.t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

            let of_stable
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  ( Limb_vector.Challenge.Constant.t
                  , Limb_vector.Challenge.Constant.t Scalar_challenge.t
                  , bool )
                  Poly.t ) : t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
          end

          (** Round-trip witness anchoring {!Constant} against {!Poly} until
              downstream consumers are migrated to the fresh record. *)
          let _ = fun (c : Constant.t) ->
            Constant.of_stable (Constant.to_stable c)

          let map_challenges t ~f ~scalar =
            { t with
              alpha = scalar t.alpha
            ; beta = f t.beta
            ; gamma = f t.gamma
            ; zeta = scalar t.zeta
            ; joint_combiner = Option.map ~f:scalar t.joint_combiner
            }

          module In_circuit = struct
            type ('challenge, 'scalar_challenge, 'bool) t =
              { alpha : 'scalar_challenge
              ; beta : 'challenge
              ; gamma : 'challenge
              ; zeta : 'scalar_challenge
              ; joint_combiner : ('scalar_challenge, 'bool) Opt.t
              ; feature_flags : 'bool Plonk_types.Features.t
              }
          end

          (** Step-circuit (Tick) instantiation of {!In_circuit.t}: the shape
              used when the Step verifier constructs Plonk-IOP challenges
              in-circuit. {!to_in_circuit} bridges to the polymorphic
              {!In_circuit.t}. *)
          module Step = struct
            type t =
              { alpha : Step_impl.Field.t Scalar_challenge.t
              ; beta : Step_impl.Field.t
              ; gamma : Step_impl.Field.t
              ; zeta : Step_impl.Field.t Scalar_challenge.t
              ; joint_combiner :
                  (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
              ; feature_flags : Step_impl.Boolean.var Plonk_types.Features.t
              }

            let to_in_circuit
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  t ) :
                ( Step_impl.Field.t
                , Step_impl.Field.t Scalar_challenge.t
                , Step_impl.Boolean.var )
                In_circuit.t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

            let of_in_circuit
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  ( Step_impl.Field.t
                  , Step_impl.Field.t Scalar_challenge.t
                  , Step_impl.Boolean.var )
                  In_circuit.t ) : t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
          end

          (** Round-trip witness anchoring {!Step} against {!In_circuit} until
              downstream consumers are migrated to the fresh record. *)
          let _ = fun (s : Step.t) -> Step.of_in_circuit (Step.to_in_circuit s)

          (** Wrap-circuit (Tock) instantiation of {!In_circuit.t}.

              Sibling of {!Step}, used when the Wrap verifier constructs
              Plonk-IOP challenges in-circuit. Fresh record; see {!Step} for
              the rationale. *)
          module Wrap = struct
            type t =
              { alpha : Wrap_impl.Field.t Scalar_challenge.t
              ; beta : Wrap_impl.Field.t
              ; gamma : Wrap_impl.Field.t
              ; zeta : Wrap_impl.Field.t Scalar_challenge.t
              ; joint_combiner :
                  (Wrap_impl.Field.t Scalar_challenge.t, Wrap_impl.Boolean.var) Opt.t
              ; feature_flags : Wrap_impl.Boolean.var Plonk_types.Features.t
              }

            let to_in_circuit
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  t ) :
                ( Wrap_impl.Field.t
                , Wrap_impl.Field.t Scalar_challenge.t
                , Wrap_impl.Boolean.var )
                In_circuit.t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

            let of_in_circuit
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  ( Wrap_impl.Field.t
                  , Wrap_impl.Field.t Scalar_challenge.t
                  , Wrap_impl.Boolean.var )
                  In_circuit.t ) : t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
          end

          (** Round-trip witness anchoring {!Wrap} against {!In_circuit} until
              downstream consumers are migrated to the fresh record. *)
          let _ = fun (w : Wrap.t) -> Wrap.of_in_circuit (Wrap.to_in_circuit w)

          (** Endo'd Tick-field instantiation of {!Stable.V1.t}.

              The prover, after running scalar challenges through
              {!Scalar_challenge.to_field_constant}, holds a Plonk.Minimal
              record where every field is a plain [Tick.Field.t] — i.e.
              both ['challenge] and ['scalar_challenge] are collapsed to
              [Tick.Field.t]. This is the shape consumed by
              {!Plonk_checks.scalars_env} when the prover prepares a wrap
              proof's deferred values for verification. {!to_stable} /
              {!of_stable} bridge to the wire-format polymorphic skeleton. *)
          module Tick = struct
            type t =
              { alpha : Backend.Tick.Field.t
              ; beta : Backend.Tick.Field.t
              ; gamma : Backend.Tick.Field.t
              ; zeta : Backend.Tick.Field.t
              ; joint_combiner : Backend.Tick.Field.t option
              ; feature_flags : bool Plonk_types.Features.t
              }
            [@@deriving sexp, compare, yojson, hlist, hash, equal]

            (** [Poly.t] specialised to [Tick] field elements — the result
                type of {!to_stable}, also the canonical shape consumed by
                [Wrap.combined_inner_product]. *)
            type poly_t = (Backend.Tick.Field.t, Backend.Tick.Field.t, bool) Poly.t

            let to_stable
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  t ) : poly_t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

            let of_stable
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  poly_t ) : t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
          end

          (** Round-trip witness anchoring {!Tick} against {!Poly} until
              downstream consumers are migrated to the fresh record. *)
          let _ = fun (t : Tick.t) -> Tick.of_stable (Tick.to_stable t)

          (** Endo'd Tock-field counterpart of {!Tick}: the shape used when
              the prover prepares a step proof's deferred values for
              verification (e.g. dummy unfinalized values). {!to_stable} /
              {!of_stable} bridge to the wire-format polymorphic skeleton. *)
          module Tock = struct
            type t =
              { alpha : Backend.Tock.Field.t
              ; beta : Backend.Tock.Field.t
              ; gamma : Backend.Tock.Field.t
              ; zeta : Backend.Tock.Field.t
              ; joint_combiner : Backend.Tock.Field.t option
              ; feature_flags : bool Plonk_types.Features.t
              }
            [@@deriving sexp, compare, yojson, hlist, hash, equal]

            let to_stable
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  t ) :
                (Backend.Tock.Field.t, Backend.Tock.Field.t, bool) Poly.t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

            let of_stable
                ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
                  (Backend.Tock.Field.t, Backend.Tock.Field.t, bool) Poly.t ) :
                t =
              { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
          end

          (** Round-trip witness anchoring {!Tock} against {!Poly} until
              downstream consumers are migrated to the fresh record. *)
          let _ = fun (t : Tock.t) -> Tock.of_stable (Tock.to_stable t)
        end

        open Pickles_types

        module In_circuit = struct
          [@@@warning "-27"]

          (* 'fp_opt is unused but kept for type compatibility with other
             In_circuit types. We suppress the warning instead of using a
             phantom type to preserve the serialization format. *)

          (** All scalar values deferred by a verifier circuit.
              We expose them so the next guy (who can do scalar arithmetic) can check that they
              were computed correctly from the evaluations in the proof and the challenges.
          *)
          type ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fp_opt
               , 'scalar_challenge_opt
               , 'bool )
               t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
                  (* TODO: zeta_to_srs_length is kind of unnecessary.
                     Try to get rid of it when you can.
                  *)
            ; zeta_to_srs_length : 'fp
            ; zeta_to_domain_size : 'fp
            ; perm : 'fp
                  (** scalar used on one of the permutation polynomial commitments. *)
            ; feature_flags : 'bool Plonk_types.Features.t
            ; joint_combiner : 'scalar_challenge_opt
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

          let map_challenges t ~f ~scalar =
            { t with
              alpha = scalar t.alpha
            ; beta = f t.beta
            ; gamma = f t.gamma
            ; joint_combiner = Opt.map ~f:scalar t.joint_combiner
            ; zeta = scalar t.zeta
            }

          let map_fields t ~f =
            { t with
              zeta_to_srs_length = f t.zeta_to_srs_length
            ; zeta_to_domain_size = f t.zeta_to_domain_size
            ; perm = f t.perm
            }

          let typ (type fp) ~dummy_scalar_challenge ~challenge ~scalar_challenge
              ~bool
              ~feature_flags:
                ({ Plonk_types.Features.Full.uses_lookups; _ } as feature_flags)
              (fp : (fp, _) Step_impl.Typ.t) =
            Step_impl.Typ.of_hlistable
              [ Scalar_challenge.typ scalar_challenge
              ; challenge
              ; challenge
              ; Scalar_challenge.typ scalar_challenge
              ; fp
              ; fp
              ; fp
              ; Plonk_types.Features.typ
                  ~feature_flags:(Plonk_types.Features.of_full feature_flags)
                  bool
              ; Opt.typ uses_lookups ~dummy:dummy_scalar_challenge
                  (Scalar_challenge.typ scalar_challenge)
              ]
              ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
              ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

          (* A sibling alias for [t] so that the concrete submodules below
             can name it without colliding with their own [t]; OCaml does
             not let the [In_circuit] module reference itself by name from
             inside its own definition. *)
          type ('a, 'b, 'c, 'd, 'e, 'f) in_circuit_t =
            ('a, 'b, 'c, 'd, 'e, 'f) t

          (** Wire-form (out-of-circuit) instantiation of {!t}.

              ['fp] left polymorphic because the constant-side scalars are
              passed around in either [_ Shifted_value.Type1.t] or
              [_ Shifted_value.Type2.t] depending on which curve's deferred
              values they describe. The ['fp_opt] phantom from the
              polymorphic {!t} is dropped (no field uses it);
              {!to_in_circuit} can produce a value at any ['fp_opt]. *)
          module Constant = struct
            type 'fp t =
              { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
              ; beta : Limb_vector.Challenge.Constant.t
              ; gamma : Limb_vector.Challenge.Constant.t
              ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
              ; zeta_to_srs_length : 'fp
              ; zeta_to_domain_size : 'fp
              ; perm : 'fp
              ; feature_flags : bool Plonk_types.Features.t
              ; joint_combiner :
                  Limb_vector.Challenge.Constant.t Scalar_challenge.t option
              }

            let to_in_circuit
                ({ alpha
                 ; beta
                 ; gamma
                 ; zeta
                 ; zeta_to_srs_length
                 ; zeta_to_domain_size
                 ; perm
                 ; feature_flags
                 ; joint_combiner
                 } :
                  'fp t ) :
                ( Limb_vector.Challenge.Constant.t
                , Limb_vector.Challenge.Constant.t Scalar_challenge.t
                , 'fp
                , _
                , Limb_vector.Challenge.Constant.t Scalar_challenge.t option
                , bool )
                in_circuit_t =
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

            let of_in_circuit
                ({ alpha
                 ; beta
                 ; gamma
                 ; zeta
                 ; zeta_to_srs_length
                 ; zeta_to_domain_size
                 ; perm
                 ; feature_flags
                 ; joint_combiner
                 } :
                  ( Limb_vector.Challenge.Constant.t
                  , Limb_vector.Challenge.Constant.t Scalar_challenge.t
                  , 'fp
                  , _
                  , Limb_vector.Challenge.Constant.t Scalar_challenge.t option
                  , bool )
                  in_circuit_t ) : 'fp t =
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
          end

          let _ = fun (c : _ Constant.t) ->
            Constant.of_in_circuit (Constant.to_in_circuit c)
        end

        let to_minimal (type challenge scalar_challenge fp fp_opt lookup_opt)
            (t :
              ( challenge
              , scalar_challenge
              , fp
              , fp_opt
              , lookup_opt
              , 'bool )
              In_circuit.t ) ~(to_option : lookup_opt -> scalar_challenge option)
            : (challenge, scalar_challenge, 'bool) Minimal.Poly.t =
          { alpha = t.alpha
          ; beta = t.beta
          ; zeta = t.zeta
          ; gamma = t.gamma
          ; joint_combiner = to_option t.joint_combiner
          ; feature_flags = t.feature_flags
          }
      end

      module Minimal = struct
        include Wire.Wrap.Proof_state.Deferred_values.Minimal

        let map_challenges { plonk; bulletproof_challenges; branch_data } ~f
            ~scalar =
          { plonk = Plonk.Minimal.map_challenges ~f ~scalar plonk
          ; bulletproof_challenges
          ; branch_data
          }
      end

      let map_challenges
          { plonk
          ; combined_inner_product
          ; b : 'fp
          ; xi
          ; bulletproof_challenges
          ; branch_data
          } ~f:_ ~scalar =
        { xi = scalar xi
        ; combined_inner_product
        ; b
        ; plonk
        ; bulletproof_challenges
        ; branch_data
        }

      module In_circuit = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fp_opt
             , 'lookup_opt
             , 'bulletproof_challenges
             , 'branch_data
             , 'bool )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fp
            , 'fp_opt
            , 'lookup_opt
            , 'bool )
            Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fp
          , 'bulletproof_challenges
          , 'branch_data )
          Stable.Latest.t
        [@@deriving sexp, compare, yojson, hash, equal]

        let to_hlist, of_hlist = (to_hlist, of_hlist)

        let typ (type fp) ~dummy_scalar_challenge ~challenge ~scalar_challenge
            ~feature_flags (fp : (fp, _) Step_impl.Typ.t) index =
          Step_impl.Typ.of_hlistable
            [ Plonk.In_circuit.typ ~dummy_scalar_challenge ~challenge
                ~scalar_challenge ~bool:Step_impl.Boolean.typ ~feature_flags fp
            ; fp
            ; fp
            ; Scalar_challenge.typ scalar_challenge
            ; Vector.typ
                (Bulletproof_challenge.typ scalar_challenge)
                Backend.Tick.Rounds.n
            ; index
            ]
            ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
            ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      end

      let to_minimal
          ({ plonk
           ; combined_inner_product = _
           ; b = _
           ; xi = _
           ; bulletproof_challenges
           ; branch_data
           } :
            _ In_circuit.t ) ~to_option : _ Minimal.t =
        { plonk = Plonk.to_minimal ~to_option plonk
        ; bulletproof_challenges
        ; branch_data
        }
    end

    (** The component of the proof accumulation state that is only computed on by the
        "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
    module Messages_for_next_wrap_proof = struct
      include Wire.Wrap.Proof_state.Messages_for_next_wrap_proof

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
      module Plonk = struct
        module Minimal = struct
          (** Challenges from the PLONK IOP. These, plus the evaluations that
              are already in the proof, are all that's needed to derive all
              the values in the [In_circuit] version below.

              See src/lib/pickles/plonk_checks/plonk_checks.ml for the
              computation of the [In_circuit] value from the [Minimal] value.
          *)
          include Wire.Step.Proof_state.Deferred_values.Plonk.Minimal

          (** Wire-format polymorphic skeleton. Concrete records below name
              it explicitly via {!Poly} rather than [include]ing it. *)
          module Poly = Wire.Step.Proof_state.Deferred_values.Plonk.Minimal

          (** Wire-form (out-of-circuit) instantiation. The
              [Step.Proof_state] tree is for step proofs (Vesta/Tick curve),
              whose challenges live in the Tock field; out of circuit those
              challenges are carried in the [Limb_vector.Challenge.Constant]
              form. *)
          module Constant = struct
            type t =
              { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
              ; beta : Limb_vector.Challenge.Constant.t
              ; gamma : Limb_vector.Challenge.Constant.t
              ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
              }
            [@@deriving sexp, compare, yojson, hlist, hash, equal]

            let to_minimal ({ alpha; beta; gamma; zeta } : t) :
                ( Limb_vector.Challenge.Constant.t
                , Limb_vector.Challenge.Constant.t Scalar_challenge.t )
                Poly.t =
              { alpha; beta; gamma; zeta }

            let of_minimal
                ({ alpha; beta; gamma; zeta } :
                  ( Limb_vector.Challenge.Constant.t
                  , Limb_vector.Challenge.Constant.t Scalar_challenge.t )
                  Poly.t ) : t =
              { alpha; beta; gamma; zeta }
          end

          let _ = fun (c : Constant.t) ->
            Constant.of_minimal (Constant.to_minimal c)

          (** Step-circuit (Tick) instantiation; used when the Step verifier
              handles step proof challenges in-circuit. *)
          module Step = struct
            type t =
              { alpha : Step_impl.Field.t Scalar_challenge.t
              ; beta : Step_impl.Field.t
              ; gamma : Step_impl.Field.t
              ; zeta : Step_impl.Field.t Scalar_challenge.t
              }

            let to_minimal ({ alpha; beta; gamma; zeta } : t) :
                (Step_impl.Field.t, Step_impl.Field.t Scalar_challenge.t) Poly.t
                =
              { alpha; beta; gamma; zeta }

            let of_minimal
                ({ alpha; beta; gamma; zeta } :
                  (Step_impl.Field.t, Step_impl.Field.t Scalar_challenge.t)
                  Poly.t ) : t =
              { alpha; beta; gamma; zeta }
          end

          let _ = fun (s : Step.t) -> Step.of_minimal (Step.to_minimal s)

          (** Wrap-circuit (Tock) instantiation. *)
          module Wrap = struct
            type t =
              { alpha : Wrap_impl.Field.t Scalar_challenge.t
              ; beta : Wrap_impl.Field.t
              ; gamma : Wrap_impl.Field.t
              ; zeta : Wrap_impl.Field.t Scalar_challenge.t
              }

            let to_minimal ({ alpha; beta; gamma; zeta } : t) :
                (Wrap_impl.Field.t, Wrap_impl.Field.t Scalar_challenge.t) Poly.t
                =
              { alpha; beta; gamma; zeta }

            let of_minimal
                ({ alpha; beta; gamma; zeta } :
                  (Wrap_impl.Field.t, Wrap_impl.Field.t Scalar_challenge.t)
                  Poly.t ) : t =
              { alpha; beta; gamma; zeta }
          end

          let _ = fun (w : Wrap.t) -> Wrap.of_minimal (Wrap.to_minimal w)
        end

        open Pickles_types

        module In_circuit = struct
          (** All scalar values deferred by a verifier circuit.
              The values in [vbmul], [complete_add], [endomul], [endomul_scalar], and [perm]
              are all scalars which will have been used to scale selector polynomials during the
              computation of the linearized polynomial commitment.

              Then, we expose them so the next guy (who can do scalar arithmetic) can check that they
              were computed correctly from the evaluations in the proof and the challenges.
          *)
          type ('challenge, 'scalar_challenge, 'fp) t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
                  (* TODO: zeta_to_srs_length is kind of unnecessary.
                     Try to get rid of it when you can.
                  *)
            ; zeta_to_srs_length : 'fp
            ; zeta_to_domain_size : 'fp
            ; perm : 'fp
                  (** scalar used on one of the permutation polynomial commitments. *)
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

          let to_wrap ~opt_none ~false_
              { alpha
              ; beta
              ; gamma
              ; zeta
              ; zeta_to_srs_length
              ; zeta_to_domain_size
              ; perm
              } : _ Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
            { alpha
            ; beta
            ; gamma
            ; zeta
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ; feature_flags =
                { range_check0 = false_
                ; range_check1 = false_
                ; foreign_field_add = false_
                ; foreign_field_mul = false_
                ; xor = false_
                ; rot = false_
                ; lookup = false_
                ; runtime_tables = false_
                }
            ; joint_combiner = opt_none
            }

          let of_wrap ~assert_none ~assert_false
              ({ alpha
               ; beta
               ; gamma
               ; zeta
               ; zeta_to_srs_length
               ; zeta_to_domain_size
               ; perm
               ; feature_flags
               ; joint_combiner
               } :
                _ Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t ) =
            let () =
              let { Plonk_types.Features.range_check0
                  ; range_check1
                  ; foreign_field_add
                  ; foreign_field_mul
                  ; xor
                  ; rot
                  ; lookup
                  ; runtime_tables
                  } =
                feature_flags
              in
              assert_false range_check0 ;
              assert_false range_check1 ;
              assert_false foreign_field_add ;
              assert_false foreign_field_mul ;
              assert_false xor ;
              assert_false rot ;
              assert_false lookup ;
              assert_false runtime_tables
            in
            assert_none joint_combiner ;
            { alpha
            ; beta
            ; gamma
            ; zeta
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            }

          let map_challenges t ~f ~scalar =
            { t with
              alpha = scalar t.alpha
            ; beta = f t.beta
            ; gamma = f t.gamma
            ; zeta = scalar t.zeta
            }

          let map_fields t ~f =
            { t with
              zeta_to_srs_length = f t.zeta_to_srs_length
            ; zeta_to_domain_size = f t.zeta_to_domain_size
            ; perm = f t.perm
            }
        end

        let to_minimal (type challenge scalar_challenge fp)
            (t : (challenge, scalar_challenge, fp) In_circuit.t) :
            (challenge, scalar_challenge) Minimal.t =
          { alpha = t.alpha; beta = t.beta; zeta = t.zeta; gamma = t.gamma }
      end

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
