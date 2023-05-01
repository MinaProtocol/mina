open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Pickles_types.Opt
open Core_kernel

type 'f impl = 'f Spec.impl

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
    module Deferred_values = struct
      module Plonk = struct
        module Minimal = struct
          [%%versioned
          module Stable = struct
            module V1 = struct
              (** Challenges from the PLONK IOP. These, plus the evaluations that are already in the proof, are
                  all that's needed to derive all the values in the [In_circuit] version below.

                  See src/lib/pickles/plonk_checks/plonk_checks.ml for the computation of the [In_circuit] value
                  from the [Minimal] value.
              *)
              type ('challenge, 'scalar_challenge, 'bool) t =
                    ( 'challenge
                    , 'scalar_challenge
                    , 'bool )
                    Mina_wire_types.Pickles_composition_types.Wrap.Proof_state
                    .Deferred_values
                    .Plonk
                    .Minimal
                    .V1
                    .t =
                { alpha : 'scalar_challenge
                ; beta : 'challenge
                ; gamma : 'challenge
                ; zeta : 'scalar_challenge
                ; joint_combiner : 'scalar_challenge option
                ; feature_flags : 'bool Plonk_types.Features.Stable.V1.t
                }
              [@@deriving sexp, compare, yojson, hlist, hash, equal]

              let to_latest = Fn.id
            end
          end]
        end

        open Pickles_types

        module In_circuit = struct
          module Lookup = struct
            type 'scalar_challenge t = { joint_combiner : 'scalar_challenge }
            [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

            let[@warning "-45"] to_struct l = Hlist.HlistId.[ l.joint_combiner ]

            let[@warning "-45"] of_struct Hlist.HlistId.[ joint_combiner ] =
              { joint_combiner }

            let map ~f { joint_combiner } =
              { joint_combiner = f joint_combiner }

            let typ scalar_challenge =
              Snarky_backendless.Typ.of_hlistable ~var_to_hlist:to_hlist
                ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
                ~value_of_hlist:of_hlist [ scalar_challenge ]
          end

          module Optional_column_scalars = struct
            include Pickles_types.Plonk_verification_key_evals.Optional_columns

            let[@warning "-45"] to_data
                { range_check0
                ; range_check1
                ; foreign_field_add
                ; foreign_field_mul
                ; xor
                ; rot
                ; lookup_gate
                ; runtime_tables
                } =
              Hlist.HlistId.
                [ range_check0
                ; range_check1
                ; foreign_field_add
                ; foreign_field_mul
                ; xor
                ; rot
                ; lookup_gate
                ; runtime_tables
                ]

            let[@warning "-45"] of_data
                Hlist.HlistId.
                  [ range_check0
                  ; range_check1
                  ; foreign_field_add
                  ; foreign_field_mul
                  ; xor
                  ; rot
                  ; lookup_gate
                  ; runtime_tables
                  ] =
              { range_check0
              ; range_check1
              ; foreign_field_add
              ; foreign_field_mul
              ; xor
              ; rot
              ; lookup_gate
              ; runtime_tables
              }

            let of_feature_flags (feature_flags : _ Plonk_types.Features.t) =
              { range_check0 = feature_flags.range_check0
              ; range_check1 = feature_flags.range_check1
              ; foreign_field_add = feature_flags.foreign_field_add
              ; foreign_field_mul = feature_flags.foreign_field_mul
              ; xor = feature_flags.xor
              ; rot = feature_flags.rot
              ; lookup_gate = feature_flags.lookup
              ; runtime_tables = feature_flags.runtime_tables
              }

            let make_opt feature_flags t =
              let flags = of_feature_flags feature_flags in
              map2 flags t ~f:(fun flag v ->
                  match v with Some v -> Opt.maybe flag v | None -> Opt.none )

            let[@warning "-45"] refine_opt feature_flags t =
              let flags = of_feature_flags feature_flags in
              map2 flags t ~f:(fun flag v ->
                  match (flag, v) with
                  | Opt.Flag.Yes, Opt.Maybe (_, v) ->
                      Opt.some v
                  | Opt.Flag.Yes, (Some _ | None) ->
                      assert false
                  | Opt.Flag.Maybe, v ->
                      v
                  | Opt.Flag.No, (None | Some _ | Maybe _) ->
                      Opt.none )

            let spec (* (type f) *) _
                (* ((module Impl) : f impl) *) (zero : _ Zero_values.t)
                (feature_flags : Plonk_types.Features.options) =
              let opt_spec flag =
                let opt_spec =
                  Spec.T.Opt_unflagged
                    { inner = B Field
                    ; flag
                    ; dummy1 = zero.value.scalar
                    ; dummy2 = zero.var.scalar
                    }
                in
                match flag with
                | Opt.Flag.No ->
                    Spec.T.Constant (None, (fun _ _ -> (* TODO *) ()), opt_spec)
                | Opt.Flag.(Yes | Maybe) ->
                    opt_spec
              in
              let [ f1; f2; f3; f4; f5; f6; f7; f8 ] =
                of_feature_flags feature_flags |> to_data
              in
              Spec.T.Struct
                [ opt_spec f1
                ; opt_spec f2
                ; opt_spec f3
                ; opt_spec f4
                ; opt_spec f5
                ; opt_spec f6
                ; opt_spec f7
                ; opt_spec f8
                ]
          end

          (** All scalar values deferred by a verifier circuit.
              The values in [vbmul], [complete_add], [endomul], [endomul_scalar], and [perm]
              are all scalars which will have been used to scale selector polynomials during the
              computation of the linearized polynomial commitment.

              Then, we expose them so the next guy (who can do scalar arithmetic) can check that they
              were computed correctly from the evaluations in the proof and the challenges.
          *)
          type ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fp_opt
               , 'lookup_opt
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
            ; vbmul : 'fp  (** scalar used on the vbmul selector *)
            ; complete_add : 'fp
                  (** scalar used on the complete_add selector *)
            ; endomul : 'fp  (** scalar used on the endomul selector *)
            ; endomul_scalar : 'fp
                  (** scalar used on the endomul_scalar selector *)
            ; perm : 'fp
                  (** scalar used on one of the permutation polynomial commitments. *)
            ; feature_flags : 'bool Plonk_types.Features.t
            ; lookup : 'lookup_opt
            ; optional_column_scalars : 'fp_opt Optional_column_scalars.t
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

          let map_challenges t ~f ~scalar =
            { t with
              alpha = scalar t.alpha
            ; beta = f t.beta
            ; gamma = f t.gamma
            ; zeta = scalar t.zeta
            ; lookup = Opt.map ~f:(Lookup.map ~f:scalar) t.lookup
            }

          let map_fields t ~f =
            { t with
              zeta_to_srs_length = f t.zeta_to_srs_length
            ; zeta_to_domain_size = f t.zeta_to_domain_size
            ; vbmul = f t.vbmul
            ; complete_add = f t.complete_add
            ; endomul = f t.endomul
            ; endomul_scalar = f t.endomul_scalar
            ; perm = f t.perm
            ; optional_column_scalars =
                Optional_column_scalars.map ~f:(Opt.map ~f)
                  t.optional_column_scalars
            }

          let typ (type f fp)
              (module Impl : Snarky_backendless.Snark_intf.Run
                with type field = f ) ~dummy_scalar ~dummy_scalar_challenge
              ~challenge ~scalar_challenge ~bool ~feature_flags
              (fp : (fp, _, f) Snarky_backendless.Typ.t) =
            Snarky_backendless.Typ.of_hlistable
              [ Scalar_challenge.typ scalar_challenge
              ; challenge
              ; challenge
              ; Scalar_challenge.typ scalar_challenge
              ; fp
              ; fp
              ; fp
              ; fp
              ; fp
              ; fp
              ; fp
              ; Plonk_types.Features.typ ~feature_flags bool
              ; Opt.typ Impl.Boolean.typ
                  feature_flags.Plonk_types.Features.lookup
                  ~dummy:{ joint_combiner = dummy_scalar_challenge }
                  (Lookup.typ (Scalar_challenge.typ scalar_challenge))
              ; Optional_column_scalars.typ
                  (module Impl)
                  ~dummy:dummy_scalar fp feature_flags
              ]
              ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
              ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
        end

        let to_minimal (type challenge scalar_challenge fp fp_opt lookup_opt)
            (t :
              ( challenge
              , scalar_challenge
              , fp
              , fp_opt
              , lookup_opt
              , 'bool )
              In_circuit.t )
            ~(to_option :
               lookup_opt -> scalar_challenge In_circuit.Lookup.t option ) :
            (challenge, scalar_challenge, 'bool) Minimal.t =
          { alpha = t.alpha
          ; beta = t.beta
          ; zeta = t.zeta
          ; gamma = t.gamma
          ; joint_combiner =
              Option.map (to_option t.lookup) ~f:(fun l ->
                  l.In_circuit.Lookup.joint_combiner )
          ; feature_flags = t.feature_flags
          }
      end

      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]

        module V1 = struct
          (** All the deferred values needed, comprising values from the PLONK IOP verification,
    values from the inner-product argument, and [which_branch] which is needed to know
    the proper domain to use. *)
          type ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'bulletproof_challenges
               , 'branch_data )
               t =
                ( 'plonk
                , 'scalar_challenge
                , 'fp
                , 'bulletproof_challenges
                , 'branch_data )
                Mina_wire_types.Pickles_composition_types.Wrap.Proof_state
                .Deferred_values
                .V1
                .t =
            { plonk : 'plonk
            ; combined_inner_product : 'fp
                  (** combined_inner_product = sum_{i < num_evaluation_points} sum_{j < num_polys} r^i xi^j f_j(pt_i) *)
            ; b : 'fp
                  (** b = challenge_poly plonk.zeta + r * challenge_poly (domain_generrator * plonk.zeta)
                where challenge_poly(x) = \prod_i (1 + bulletproof_challenges.(i) * x^{2^{k - 1 - i}})
            *)
            ; xi : 'scalar_challenge
                  (** The challenge used for combining polynomials *)
            ; bulletproof_challenges : 'bulletproof_challenges
                  (** The challenges from the inner-product argument that was partially verified. *)
            ; branch_data : 'branch_data
                  (** Data specific to which step branch of the proof-system was verified *)
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal]

          let to_latest = Fn.id
        end
      end]

      type ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'bulletproof_challenges
           , 'branch_data )
           t =
            ( 'plonk
            , 'scalar_challenge
            , 'fp
            , 'bulletproof_challenges
            , 'branch_data )
            Stable.Latest.t =
        { plonk : 'plonk
        ; combined_inner_product : 'fp
        ; b : 'fp
        ; xi : 'scalar_challenge
        ; bulletproof_challenges : 'bulletproof_challenges
        ; branch_data : 'branch_data
        }
      [@@deriving sexp, compare, yojson, hlist, hash, equal]

      module Minimal = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'bool
             , 'bulletproof_challenges
             , 'index )
             t =
          ( ('challenge, 'scalar_challenge, 'bool) Plonk.Minimal.t
          , 'scalar_challenge
          , 'fp
          , 'bulletproof_challenges
          , 'index )
          Stable.Latest.t
        [@@deriving sexp, compare, yojson, hash, equal]
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

        let typ (type f fp)
            ((module Impl) as impl :
              (module Snarky_backendless.Snark_intf.Run with type field = f) )
            ~dummy_scalar ~dummy_scalar_challenge ~challenge ~scalar_challenge
            ~feature_flags (fp : (fp, _, f) Snarky_backendless.Typ.t) index =
          Snarky_backendless.Typ.of_hlistable
            [ Plonk.In_circuit.typ impl ~dummy_scalar ~dummy_scalar_challenge
                ~challenge ~scalar_challenge ~bool:Impl.Boolean.typ
                ~feature_flags fp
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

      let to_minimal (t : _ In_circuit.t) ~to_option : _ Minimal.t =
        { t with plonk = Plonk.to_minimal ~to_option t.plonk }
    end

    (** The component of the proof accumulation state that is only computed on by the
        "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
    module Messages_for_next_wrap_proof = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ('g1, 'bulletproof_challenges) t =
                ( 'g1
                , 'bulletproof_challenges )
                Mina_wire_types.Pickles_composition_types.Wrap.Proof_state
                .Messages_for_next_wrap_proof
                .V1
                .t =
            { challenge_polynomial_commitment : 'g1
            ; old_bulletproof_challenges : 'bulletproof_challenges
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal]
        end
      end]

      let to_field_elements (type g f)
          { challenge_polynomial_commitment; old_bulletproof_challenges }
          ~g1:(g1_to_field_elements : g -> f list) =
        Array.concat
          [ Vector.to_array old_bulletproof_challenges
            |> Array.concat_map ~f:Vector.to_array
          ; Array.of_list (g1_to_field_elements challenge_polynomial_commitment)
          ]

      let typ g1 chal ~length =
        Snarky_backendless.Typ.of_hlistable
          [ g1; Vector.typ chal length ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'messages_for_next_wrap_proof
             , 'digest
             , 'bp_chals
             , 'index )
             t =
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'messages_for_next_wrap_proof
              , 'digest
              , 'bp_chals
              , 'index )
              Mina_wire_types.Pickles_composition_types.Wrap.Proof_state.V1.t =
          { deferred_values :
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'bp_chals
              , 'index )
              Deferred_values.Stable.V1.t
          ; sponge_digest_before_evaluations : 'digest
          ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
                (** Parts of the statement not needed by the other circuit. Represented as a hash inside the
              circuit which is then "unhashed". *)
          }
        [@@deriving sexp, compare, yojson, hlist, hash, equal]
      end
    end]

    module Minimal = struct
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'bool
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ('challenge, 'scalar_challenge, 'bool) Deferred_values.Plonk.Minimal.t
        , 'scalar_challenge
        , 'fp
        , 'messages_for_next_wrap_proof
        , 'digest
        , 'bp_chals
        , 'index )
        Stable.Latest.t
      [@@deriving sexp, compare, yojson, hash, equal]
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

      let typ (type f fp)
          (impl : (module Snarky_backendless.Snark_intf.Run with type field = f))
          ~dummy_scalar ~dummy_scalar_challenge ~challenge ~scalar_challenge
          ~feature_flags (fp : (fp, _, f) Snarky_backendless.Typ.t)
          messages_for_next_wrap_proof digest index =
        Snarky_backendless.Typ.of_hlistable
          [ Deferred_values.In_circuit.typ impl ~dummy_scalar
              ~dummy_scalar_challenge ~challenge ~scalar_challenge
              ~feature_flags fp index
          ; digest
          ; messages_for_next_wrap_proof
          ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist
    end

    let to_minimal (t : _ In_circuit.t) ~to_option : _ Minimal.t =
      { t with
        deferred_values =
          Deferred_values.to_minimal ~to_option t.deferred_values
      }
  end

  (** The component of the proof accumulation state that is only computed on by the
      "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
  module Messages_for_next_step_proof = struct
    type ( 'g
         , 'g_opt
         , 's
         , 'challenge_polynomial_commitments
         , 'bulletproof_challenges )
         t =
      { app_state : 's
            (** The actual application-level state (e.g., for Mina, this is the protocol state which contains the
    merkle root of the ledger, state related to consensus, etc.) *)
      ; dlog_plonk_index :
          ('g, 'g_opt) Pickles_types.Plonk_verification_key_evals.t
            (** The verification key corresponding to the wrap-circuit for this
                recursive proof system.  It gets threaded through all the
                circuits so that the step circuits can verify proofs against
                it.  *)
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
        [ index_to_field_elements ~g:comm
            ~g_opt:(function None -> [||] | Some v -> comm v)
            dlog_plonk_index
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

    let typ _comm _commopt g s chal proofs_verified =
      Snarky_backendless.Typ.of_hlistable
        [ s; assert false; Vector.typ g proofs_verified; chal ]
        (* TODO: Should this really just be a vector typ of length Rounds.n ?*)
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Lookup_parameters = struct
    (* Values needed for computing lookup parts of the verifier circuit. *)
    type ('chal, 'chal_var, 'fp, 'fp_var) t =
      { zero : ('chal, 'chal_var, 'fp, 'fp_var) Zero_values.t
      ; use : Opt.Flag.t
      }

    let opt_spec (type f) ((module Impl) : f impl)
        { zero = { value; var }; use } =
      Spec.T.Opt
        { inner = Struct [ Scalar Challenge ]
        ; flag = use
        ; dummy1 =
            [ Kimchi_backend_common.Scalar_challenge.create value.challenge ]
        ; dummy2 =
            [ Kimchi_backend_common.Scalar_challenge.create var.challenge ]
        ; bool = (module Impl.Boolean)
        }
  end

  (** This is the full statement for "wrap" proofs which contains
      - the application-level statement (app_state)
      - data needed to perform the final verification of the proof, which correspond
        to parts of incompletely verified proofs.
  *)
  module Statement = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'messages_for_next_wrap_proof
             , 'digest
             , 'messages_for_next_step_proof
             , 'bp_chals
             , 'index )
             t =
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'messages_for_next_wrap_proof
              , 'digest
              , 'messages_for_next_step_proof
              , 'bp_chals
              , 'index )
              Mina_wire_types.Pickles_composition_types.Wrap.Statement.V1.t =
          { proof_state :
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'messages_for_next_wrap_proof
              , 'digest
              , 'bp_chals
              , 'index )
              Proof_state.Stable.V1.t
          ; messages_for_next_step_proof : 'messages_for_next_step_proof
          }
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    module Minimal = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'bool
               , 'messages_for_next_wrap_proof
               , 'digest
               , 'messages_for_next_step_proof
               , 'bp_chals
               , 'index )
               t =
            ( ( 'challenge
              , 'scalar_challenge
              , 'bool )
              Proof_state.Deferred_values.Plonk.Minimal.Stable.V1.t
            , 'scalar_challenge
            , 'fp
            , 'messages_for_next_wrap_proof
            , 'digest
            , 'messages_for_next_step_proof
            , 'bp_chals
            , 'index )
            Stable.V1.t
          [@@deriving compare, yojson, sexp, hash, equal]
        end
      end]
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
      let spec impl lookup feature_flags =
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
          [ Vector (B Field, Nat.N9.n)
          ; Vector (B Challenge, Nat.N2.n)
          ; Vector (Scalar Challenge, Nat.N3.n)
          ; Vector (B Digest, Nat.N3.n)
          ; Vector (B Bulletproof_challenge, Backend.Tick.Rounds.n)
          ; Vector (B Branch_data, Nat.N1.n)
          ; feature_flags_spec
          ; Lookup_parameters.opt_spec impl lookup
          ; Proof_state.Deferred_values.Plonk.In_circuit.Optional_column_scalars
            .spec impl lookup.zero feature_flags
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
                       ; vbmul
                       ; complete_add
                       ; endomul
                       ; endomul_scalar
                       ; perm
                       ; feature_flags
                       ; lookup
                       ; optional_column_scalars
                       }
                   }
               ; sponge_digest_before_evaluations
               ; messages_for_next_wrap_proof
                 (* messages_for_next_wrap_proof is represented as a digest (and then unhashed) inside the circuit *)
               }
           ; messages_for_next_step_proof
             (* messages_for_next_step_proof is represented as a digest inside the circuit *)
           } :
            _ t ) ~option_map ~to_opt =
        let open Vector in
        let fp =
          [ combined_inner_product
          ; b
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; vbmul
          ; complete_add
          ; endomul
          ; endomul_scalar
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
        let optional_column_scalars =
          let open
            Proof_state.Deferred_values.Plonk.In_circuit.Optional_column_scalars in
          optional_column_scalars |> map ~f:to_opt |> to_data
        in
        Hlist.HlistId.
          [ fp
          ; challenge
          ; scalar_challenge
          ; digest
          ; bulletproof_challenges
          ; index
          ; Plonk_types.Features.to_data feature_flags
          ; option_map lookup
              ~f:Proof_state.Deferred_values.Plonk.In_circuit.Lookup.to_struct
          ; optional_column_scalars
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
            ; lookup
            ; optional_column_scalars
            ] ~feature_flags:flags ~option_map ~of_opt : _ t =
        let open Vector in
        let [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; vbmul
            ; complete_add
            ; endomul
            ; endomul_scalar
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
        let optional_column_scalars =
          let open
            Proof_state.Deferred_values.Plonk.In_circuit.Optional_column_scalars in
          of_data optional_column_scalars
          |> make_opt feature_flags |> refine_opt flags |> map ~f:of_opt
        in
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
                    ; vbmul
                    ; complete_add
                    ; endomul
                    ; endomul_scalar
                    ; perm
                    ; feature_flags
                    ; lookup =
                        option_map lookup
                          ~f:
                            Proof_state.Deferred_values.Plonk.In_circuit.Lookup
                            .of_struct
                    ; optional_column_scalars
                    }
                }
            ; sponge_digest_before_evaluations
            ; messages_for_next_wrap_proof
            }
        ; messages_for_next_step_proof
        }
    end

    let to_minimal (t : _ In_circuit.t) ~to_option : _ Minimal.t =
      { t with proof_state = Proof_state.to_minimal ~to_option t.proof_state }
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
      module Plonk = Wrap.Proof_state.Deferred_values.Plonk

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
        type ( 'challenge
             , 'scalar_challenge
             , 'bool
             , 'fq
             , 'bulletproof_challenges )
             t =
          ( ('challenge, 'scalar_challenge, 'bool) Plonk.Minimal.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges )
          t_
        [@@deriving sexp, compare, yojson]
      end

      module In_circuit = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'fq_opt
             , 'bool
             , 'bulletproof_challenges )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fq
            , 'fq_opt
            , ('scalar_challenge Plonk.In_circuit.Lookup.t, 'bool) Opt.t
            , 'bool )
            Plonk.In_circuit.t
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
          ( ( 'challenge
            , 'scalar_challenge
            , 'bool )
            Deferred_values.Plonk.Minimal.t
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
             , 'fq_opt
             , 'lookup_opt
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fq
            , 'fq_opt
            , 'lookup_opt
            , 'bool )
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
        let spec impl bp_log2 lookup feature_flags =
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
            [ Vector (B Field, Nat.N9.n)
            ; Vector (B Digest, Nat.N1.n)
            ; Vector (B Challenge, Nat.N2.n)
            ; Vector (Scalar Challenge, Nat.N3.n)
            ; Vector (B Bulletproof_challenge, bp_log2)
            ; Vector (B Bool, Nat.N1.n)
            ; feature_flags_spec
            ; Wrap.Lookup_parameters.opt_spec impl lookup
            ; Wrap.Proof_state.Deferred_values.Plonk.In_circuit
              .Optional_column_scalars
              .spec impl lookup.zero feature_flags
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
                     ; vbmul
                     ; complete_add
                     ; endomul
                     ; endomul_scalar
                     ; perm
                     ; feature_flags
                     ; lookup
                     ; optional_column_scalars
                     }
                 }
             ; should_finalize
             ; sponge_digest_before_evaluations
             } :
              _ t ) ~option_map ~to_opt =
          let open Vector in
          let fq =
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; vbmul
            ; complete_add
            ; endomul
            ; endomul_scalar
            ; perm
            ]
          in
          let challenge = [ beta; gamma ] in
          let scalar_challenge = [ alpha; zeta; xi ] in
          let digest = [ sponge_digest_before_evaluations ] in
          let bool = [ should_finalize ] in
          let optional_column_scalars =
            let open Deferred_values.Plonk.In_circuit.Optional_column_scalars in
            optional_column_scalars |> map ~f:to_opt |> to_data
          in
          let open Hlist.HlistId in
          [ fq
          ; digest
          ; challenge
          ; scalar_challenge
          ; bulletproof_challenges
          ; bool
          ; Plonk_types.Features.to_data feature_flags
          ; option_map lookup
              ~f:Deferred_values.Plonk.In_circuit.Lookup.to_struct
          ; optional_column_scalars
          ]

        let[@warning "-45"] of_data
            Hlist.HlistId.
              [ Vector.
                  [ combined_inner_product
                  ; b
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; vbmul
                  ; complete_add
                  ; endomul
                  ; endomul_scalar
                  ; perm
                  ]
              ; Vector.[ sponge_digest_before_evaluations ]
              ; Vector.[ beta; gamma ]
              ; Vector.[ alpha; zeta; xi ]
              ; bulletproof_challenges
              ; Vector.[ should_finalize ]
              ; feature_flags
              ; lookup
              ; optional_column_scalars
              ] ~feature_flags:flags ~option_map ~of_opt : _ t =
          let feature_flags = Plonk_types.Features.of_data feature_flags in
          let optional_column_scalars =
            let open Deferred_values.Plonk.In_circuit.Optional_column_scalars in
            of_data optional_column_scalars
            |> make_opt feature_flags |> refine_opt flags |> map ~f:of_opt
          in
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
                  ; vbmul
                  ; complete_add
                  ; endomul
                  ; endomul_scalar
                  ; perm
                  ; feature_flags
                  ; lookup =
                      option_map lookup
                        ~f:Deferred_values.Plonk.In_circuit.Lookup.of_struct
                  ; optional_column_scalars
                  }
              }
          ; should_finalize
          ; sponge_digest_before_evaluations
          }

        let map_lookup (t : _ t) ~f =
          { t with
            deferred_values =
              { t.deferred_values with
                plonk =
                  { t.deferred_values.plonk with
                    lookup = f t.deferred_values.plonk.lookup
                  }
              }
          }
      end

      let typ impl fq ~assert_16_bits ~zero ~feature_flags =
        let lookup_config =
          { Wrap.Lookup_parameters.use =
              feature_flags.Plonk_types.Features.lookup
          ; zero
          }
        in
        let open In_circuit in
        Spec.typ impl fq ~assert_16_bits
          (spec impl Backend.Tock.Rounds.n lookup_config feature_flags)
        |> Snarky_backendless.Typ.transport
             ~there:(to_data ~option_map:Option.map ~to_opt:Fn.id)
             ~back:
               (of_data ~option_map:Option.map ~feature_flags
                  ~of_opt:Opt.to_option )
        |> Snarky_backendless.Typ.transport_var
             ~there:(to_data ~option_map:Opt.map ~to_opt:Opt.to_option_unsafe)
             ~back:(of_data ~option_map:Opt.map ~feature_flags ~of_opt:Fn.id)
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

    include struct
      open Hlist.HlistId

      let _to_data { unfinalized_proofs; messages_for_next_step_proof } =
        [ Vector.map unfinalized_proofs ~f:Per_proof.In_circuit.to_data
        ; messages_for_next_step_proof
        ]

      let _of_data [ unfinalized_proofs; messages_for_next_step_proof ] =
        { unfinalized_proofs =
            Vector.map unfinalized_proofs ~f:Per_proof.In_circuit.of_data
        ; messages_for_next_step_proof
        }
    end [@@warning "-45"]

    let[@warning "-60"] typ (type n f)
        ( (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
        as impl ) zero ~assert_16_bits
        (proofs_verified : (Plonk_types.Features.options, n) Vector.t) fq :
        ( ((_, _) Vector.t, _) t
        , ((_, _) Vector.t, _) t
        , _ )
        Snarky_backendless.Typ.t =
      let per_proof feature_flags =
        Per_proof.typ impl fq ~feature_flags ~assert_16_bits ~zero
      in
      let unfinalized_proofs =
        Vector.typ' (Vector.map proofs_verified ~f:per_proof)
      in
      let messages_for_next_step_proof =
        Spec.typ impl fq ~assert_16_bits (B Spec.Digest)
      in
      Snarky_backendless.Typ.of_hlistable
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
        } ~option_map ~to_opt =
      let open Hlist.HlistId in
      [ Vector.map unfinalized_proofs
          ~f:(Proof_state.Per_proof.In_circuit.to_data ~option_map ~to_opt)
      ; messages_for_next_step_proof
      ; messages_for_next_wrap_proof
      ]

    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ unfinalized_proofs
          ; messages_for_next_step_proof
          ; messages_for_next_wrap_proof
          ] ~feature_flags ~option_map ~of_opt =
      { proof_state =
          { unfinalized_proofs =
              Vector.map unfinalized_proofs
                ~f:
                  (Proof_state.Per_proof.In_circuit.of_data ~feature_flags
                     ~option_map ~of_opt )
          ; messages_for_next_step_proof
          }
      ; messages_for_next_wrap_proof
      }

    let spec impl proofs_verified bp_log2 lookup feature_flags =
      let per_proof =
        Proof_state.Per_proof.In_circuit.spec impl bp_log2 lookup feature_flags
      in
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
  type 'n t =
    (Backend.Tock.Field.t Snarky_backendless.Cvar.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Backend.Tock.Field.t Wrap_bp_vec.t, 'n) Vector.t
  end
end
