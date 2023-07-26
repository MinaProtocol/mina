open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Plonk_types.Opt
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

          let map_challenges t ~f ~scalar =
            { t with
              alpha = scalar t.alpha
            ; beta = f t.beta
            ; gamma = f t.gamma
            ; zeta = scalar t.zeta
            ; joint_combiner = Option.map ~f:scalar t.joint_combiner
            }
        end

        open Pickles_types

        module In_circuit = struct
          module Lookup = struct
            type 'scalar_challenge t = { joint_combiner : 'scalar_challenge }
            [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

            let to_struct l = Hlist.HlistId.[ l.joint_combiner ]

            let of_struct Hlist.HlistId.[ joint_combiner ] = { joint_combiner }

            let map ~f { joint_combiner } =
              { joint_combiner = f joint_combiner }

            let typ (type f fp) scalar_challenge =
              Snarky_backendless.Typ.of_hlistable ~var_to_hlist:to_hlist
                ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
                ~value_of_hlist:of_hlist [ scalar_challenge ]
          end

          (** All scalar values deferred by a verifier circuit.
              We expose them so the next guy (who can do scalar arithmetic) can check that they
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
            ; perm : 'fp
                  (** scalar used on one of the permutation polynomial commitments. *)
            ; feature_flags : 'bool Plonk_types.Features.t
            ; lookup : 'lookup_opt
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
            ; perm = f t.perm
            }

          let typ (type f fp)
              (module Impl : Snarky_backendless.Snark_intf.Run
                with type field = f ) ~dummy_scalar ~dummy_scalar_challenge
              ~challenge ~scalar_challenge ~bool ~feature_flags
              (fp : (fp, _, f) Snarky_backendless.Typ.t) =
            let uses_lookup =
              let { Plonk_types.Features.range_check0
                  ; range_check1
                  ; foreign_field_add = _ (* Doesn't use lookup *)
                  ; foreign_field_mul
                  ; xor
                  ; rot
                  ; lookup
                  ; runtime_tables = _ (* Fixme *)
                  } =
                feature_flags
              in
              Array.reduce_exn ~f:Opt.Flag.( ||| )
                [| range_check0
                 ; range_check1
                 ; foreign_field_mul
                 ; xor
                 ; rot
                 ; lookup
                |]
            in
            Snarky_backendless.Typ.of_hlistable
              [ Scalar_challenge.typ scalar_challenge
              ; challenge
              ; challenge
              ; Scalar_challenge.typ scalar_challenge
              ; fp
              ; fp
              ; fp
              ; Plonk_types.Features.typ ~feature_flags bool
              ; Plonk_types.Opt.typ Impl.Boolean.typ uses_lookup
                  ~dummy:{ joint_combiner = dummy_scalar_challenge }
                  (Lookup.typ (Scalar_challenge.typ scalar_challenge))
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
        [%%versioned
        module Stable = struct
          module V1 = struct
            type ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'bool
                 , 'bulletproof_challenges
                 , 'branch_data )
                 t =
                  ( 'challenge
                  , 'scalar_challenge
                  , 'fp
                  , 'bool
                  , 'bulletproof_challenges
                  , 'branch_data )
                  Mina_wire_types.Pickles_composition_types.Wrap.Proof_state
                  .Deferred_values
                  .Minimal
                  .V1
                  .t =
              { plonk :
                  ( 'challenge
                  , 'scalar_challenge
                  , 'bool )
                  Plonk.Minimal.Stable.V1.t
              ; bulletproof_challenges : 'bulletproof_challenges
              ; branch_data : 'branch_data
              }
            [@@deriving sexp, compare, yojson, hash, equal]
          end
        end]

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
          } ~f ~scalar =
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

      let to_minimal
          ({ plonk
           ; combined_inner_product
           ; b
           ; xi
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
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'bool
               , 'messages_for_next_wrap_proof
               , 'digest
               , 'bp_chals
               , 'index )
               t =
                ( 'challenge
                , 'scalar_challenge
                , 'fp
                , 'bool
                , 'messages_for_next_wrap_proof
                , 'digest
                , 'bp_chals
                , 'index )
                Mina_wire_types.Pickles_composition_types.Wrap.Proof_state
                .Minimal
                .V1
                .t =
            { deferred_values :
                ( 'challenge
                , 'scalar_challenge
                , 'fp
                , 'bool
                , 'bp_chals
                , 'index )
                Deferred_values.Minimal.Stable.V1.t
            ; sponge_digest_before_evaluations : 'digest
            ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
                  (** Parts of the statement not needed by the other circuit. Represented as a hash inside the
              circuit which is then "unhashed". *)
            }
          [@@deriving sexp, compare, yojson, hash, equal]
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

    let to_hlist
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

    let of_hlist
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

    let typ comm g s chal proofs_verified =
      Snarky_backendless.Typ.of_hlistable
        [ s
        ; Plonk_verification_key_evals.typ comm
        ; Vector.typ g proofs_verified
        ; chal
        ]
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
                ( 'challenge
                , 'scalar_challenge
                , 'fp
                , 'bool
                , 'messages_for_next_wrap_proof
                , 'digest
                , 'messages_for_next_step_proof
                , 'bp_chals
                , 'index )
                Mina_wire_types.Pickles_composition_types.Wrap.Statement.Minimal
                .V1
                .t =
            { proof_state :
                ( 'challenge
                , 'scalar_challenge
                , 'fp
                , 'bool
                , 'messages_for_next_wrap_proof
                , 'digest
                , 'bp_chals
                , 'index )
                Proof_state.Minimal.Stable.V1.t
            ; messages_for_next_step_proof : 'messages_for_next_step_proof
            }
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
            | Plonk_types.Opt.Flag.Yes ->
                constant true
            | Plonk_types.Opt.Flag.No ->
                constant false
            | Plonk_types.Opt.Flag.Maybe ->
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
          ; Lookup_parameters.opt_spec impl lookup
          ]

      (** Convert a statement (as structured data) into the flat data-based representation. *)
      let to_data
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
                       ; lookup
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
          ; option_map lookup
              ~f:Proof_state.Deferred_values.Plonk.In_circuit.Lookup.to_struct
          ]

      (** Construct a statement (as structured data) from the flat data-based representation. *)
      let of_data
          Hlist.HlistId.
            [ fp
            ; challenge
            ; scalar_challenge
            ; digest
            ; bulletproof_challenges
            ; index
            ; feature_flags
            ; lookup
            ] ~feature_flags:flags ~option_map ~of_opt : _ t =
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
                    ; lookup =
                        option_map lookup
                          ~f:
                            Proof_state.Deferred_values.Plonk.In_circuit.Lookup
                            .of_struct
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
          [%%versioned
          module Stable = struct
            module V1 = struct
              (** Challenges from the PLONK IOP. These, plus the evaluations that are already in the proof, are
                  all that's needed to derive all the values in the [In_circuit] version below.

                  See src/lib/pickles/plonk_checks/plonk_checks.ml for the computation of the [In_circuit] value
                  from the [Minimal] value.
              *)
              type ('challenge, 'scalar_challenge) t =
                { alpha : 'scalar_challenge
                ; beta : 'challenge
                ; gamma : 'challenge
                ; zeta : 'scalar_challenge
                }
              [@@deriving sexp, compare, yojson, hlist, hash, equal]

              let to_latest = Fn.id
            end
          end]

          let to_wrap ~feature_flags { alpha; beta; gamma; zeta } :
              _ Wrap.Proof_state.Deferred_values.Plonk.Minimal.t =
            { alpha; beta; gamma; zeta; joint_combiner = None; feature_flags }

          let of_wrap
              ({ alpha; beta; gamma; zeta; joint_combiner = _; feature_flags } :
                _ Wrap.Proof_state.Deferred_values.Plonk.Minimal.t ) =
            { alpha; beta; gamma; zeta }
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
            ; lookup = opt_none
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
               ; lookup
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
            assert_none lookup ;
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
              ]
              ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
              ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
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
          ( ('challenge, 'scalar_challenge) Plonk.Minimal.t
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
          ( ('challenge, 'scalar_challenge) Deferred_values.Plonk.Minimal.t
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

        let to_data
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

        let of_data
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

      let typ impl fq ~assert_16_bits ~zero =
        let open In_circuit in
        Spec.typ impl fq ~assert_16_bits (spec Backend.Tock.Rounds.n)
        |> Snarky_backendless.Typ.transport ~there:to_data ~back:of_data
        |> Snarky_backendless.Typ.transport_var ~there:to_data ~back:of_data
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

      let to_data { unfinalized_proofs; messages_for_next_step_proof } =
        [ Vector.map unfinalized_proofs ~f:Per_proof.In_circuit.to_data
        ; messages_for_next_step_proof
        ]

      let of_data [ unfinalized_proofs; messages_for_next_step_proof ] =
        { unfinalized_proofs =
            Vector.map unfinalized_proofs ~f:Per_proof.In_circuit.of_data
        ; messages_for_next_step_proof
        }
    end

    let typ (type n f)
        ( (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
        as impl ) zero ~assert_16_bits
        (proofs_verified :
          (Plonk_types.Opt.Flag.t Plonk_types.Features.t, n) Vector.t ) fq :
        ( ((_, _) Vector.t, _) t
        , ((_, _) Vector.t, _) t
        , _ )
        Snarky_backendless.Typ.t =
      let per_proof feature_flags =
        Per_proof.typ impl fq ~assert_16_bits ~zero
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

    let to_data
        { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
        ; messages_for_next_wrap_proof
        } =
      let open Hlist.HlistId in
      [ Vector.map unfinalized_proofs
          ~f:Proof_state.Per_proof.In_circuit.to_data
      ; messages_for_next_step_proof
      ; messages_for_next_wrap_proof
      ]

    let of_data
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
  type 'n t =
    (Backend.Tock.Field.t Snarky_backendless.Cvar.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Backend.Tock.Field.t Wrap_bp_vec.t, 'n) Vector.t
  end
end
