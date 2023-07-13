open Pickles_types
module Opt = Plonk_types.Opt

type ('a, 'b) opt := ('a, 'b) Opt.t

type ('var, 'value, 'field, 'checked) snarky_typ :=
  ('var, 'value, 'field, 'checked) Snarky_backendless.Types.Typ.t

(** {2 Module aliases} *)

module Digest = Digest
module Spec = Spec
module Branch_data = Branch_data
module Bulletproof_challenge = Bulletproof_challenge
module Nvector = Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge

(** {2 Modules} *)

module Zero_values : sig
  type ('chal, 'fp) single = { challenge : 'chal; scalar : 'fp }

  type ('chal, 'chal_var, 'fp, 'fp_var) t =
    { value : ('chal, 'fp) single; var : ('chal_var, 'fp_var) single }
end

module Wrap : sig
  module Proof_state : sig
    (** This module contains structures which contain the scalar-field elements
      that are required to finalize the verification of a proof that is
      partially verified inside a circuit.

      Each verifier circuit starts by verifying the parts of a proof involving
      group operations.  At the end, there is a sequence of scalar-field
      computations it must perform. Instead of performing them directly, it
      exposes the values needed for those computations as a part of its own
      public-input, so that the next circuit can do them (since it will use the
      other curve on the cycle, and hence can efficiently perform computations
      in that scalar field). *)
    module Deferred_values : sig
      module Plonk : sig
        module Minimal : sig
          [%%versioned:
          module Stable : sig
            module V1 : sig
              (** Challenges from the PLONK IOP. These, plus the evaluations
                  that are already in the proof, are all that's needed to derive
                  all the values in the {!module:In_circuit} version below.

                  See src/lib/pickles/plonk_checks/plonk_checks.ml for the
                  computation of the {!module:In_circuit} value from the
                  {!module:Minimal} value.  *)
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
                ; feature_flags : 'bool Plonk_types.Features.t
                }
              [@@deriving sexp, compare, yojson, hlist, hash, equal]

              val to_latest : 'a -> 'a
            end
          end]
        end

        module In_circuit : sig
          module Lookup : sig
            type 'scalar_challenge t = { joint_combiner : 'scalar_challenge }
            [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

            val to_struct : 'a t -> ('a * unit) Hlist.HlistId.t

            val of_struct : ('a * unit) Hlist.HlistId.t -> 'a t

            val typ :
                 ( 'a
                 , 'b
                 , 'f
                 , ( unit
                   , 'f )
                   Snarky_backendless.Checked_runner.Simple.Types.Checked.t )
                 Snarky_backendless.Types.Typ.t
              -> ('a t, 'b t, 'f) Snarky_backendless.Typ.t
          end

          (** All scalar values deferred by a verifier circuit.

              The values in [vbmul], [complete_add], [endomul],
              [endomul_scalar], [perm], and are all scalars which will have
              been used to scale selector polynomials during the computation of
              the linearized polynomial commitment.

              Then, we expose them so the next guy (who can do scalar
              arithmetic) can check that they were computed correctly from the
              evaluations in the proof and the challenges.  *)
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
            ; zeta_to_srs_length : 'fp
            ; zeta_to_domain_size : 'fp
            ; perm : 'fp
                  (** scalar used on one of the permutation polynomial commitments. *)
            ; feature_flags : 'bool Plonk_types.Features.t
            ; lookup : 'lookup_opt
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

          val map_challenges :
               ('a, 'b, 'c, 'fp_opt, ('b Lookup.t, 'e) Opt.t, 'bool) t
            -> f:('a -> 'f)
            -> scalar:('b -> 'g)
            -> ('f, 'g, 'c, 'fp_opt, ('g Lookup.t, 'e) Opt.t, 'bool) t

          val map_fields :
               ('a, 'b, 'c, ('c, 'e) Opt.t, ('d Lookup.t, 'e) Opt.t, 'bool) t
            -> f:('c -> 'f)
            -> ('a, 'b, 'f, ('f, 'e) Opt.t, ('d Lookup.t, 'e) Opt.t, 'bool) t

          val typ :
               'f Spec.impl
            -> dummy_scalar:'a
            -> dummy_scalar_challenge:'b Scalar_challenge.t
            -> challenge:
                 ( 'c
                 , 'd
                 , 'f
                 , ( unit
                   , 'f )
                   Snarky_backendless.Checked_runner.Simple.Types.Checked.t )
                 Snarky_backendless.Types.Typ.t
            -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
            -> bool:
                 ( ('f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
                    as
                    'boolean )
                 , bool
                 , 'f )
                 Snarky_backendless.Typ.t
            -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
            -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
            -> ( ( 'c
                 , 'e Scalar_challenge.t
                 , 'fp
                 , ('fp, 'boolean) Plonk_types.Opt.t
                 , ('e Scalar_challenge.t Lookup.t, 'boolean) Plonk_types.Opt.t
                 , 'boolean )
                 t
               , ( 'd
                 , 'b Scalar_challenge.t
                 , 'a
                 , 'a option
                 , 'b Scalar_challenge.t Lookup.t option
                 , bool )
                 t
               , 'f )
               Snarky_backendless.Typ.t
        end

        val to_minimal :
             ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fp_opt
             , 'lookup_opt
             , 'bool )
             In_circuit.t
          -> to_option:
               ('lookup_opt -> 'scalar_challenge In_circuit.Lookup.t option)
          -> ('challenge, 'scalar_challenge, 'bool) Minimal.t
      end

      module Stable : sig
        module V1 : sig
          (** All the deferred values needed, comprising values from the PLONK
              IOP verification, values from the inner-product argument, and
              [which_branch] which is needed to know the proper domain to
              use. *)
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

          val to_latest : 'a -> 'a
        end

        module Latest = V1
      end

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

      type ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'bulletproof_challenges
           , 'branch_data )
           w :=
        ( 'plonk
        , 'scalar_challenge
        , 'fp
        , 'bulletproof_challenges
        , 'branch_data )
        t

      val map_challenges :
           ('a, 'b, 'fp, 'c, 'd) t
        -> f:'e
        -> scalar:('b -> 'f)
        -> ('a, 'f, 'fp, 'c, 'd) t

      module Minimal : sig
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

      module In_circuit : sig
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

        val typ :
             (module Snarky_backendless.Snark_intf.Run with type field = 'f)
          -> dummy_scalar:'a
          -> dummy_scalar_challenge:'b Scalar_challenge.t
          -> challenge:
               ( 'c
               , 'd
               , 'f
               , ( unit
                 , 'f )
                 Snarky_backendless.Checked_runner.Simple.Types.Checked.t )
               snarky_typ
          -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
          -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
          -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
          -> ( 'g
             , 'h
             , 'f
             , ( unit
               , 'f )
               Snarky_backendless.Checked_runner.Simple.Types.Checked.t )
             snarky_typ
          -> ( ( ( 'c
                 , 'e Scalar_challenge.t
                 , 'fp
                 , ( 'fp
                   , 'f Snarky_backendless.Cvar.t
                     Snarky_backendless__Snark_intf.Boolean0.t )
                   Plonk_types.Opt.t
                 , ( 'e Scalar_challenge.t Plonk.In_circuit.Lookup.t
                   , 'f Snarky_backendless.Cvar.t
                     Snarky_backendless__Snark_intf.Boolean0.t )
                   Plonk_types.Opt.t
                 , 'f Snarky_backendless.Cvar.t
                   Snarky_backendless__Snark_intf.Boolean0.t )
                 Plonk.In_circuit.t
               , 'e Scalar_challenge.t
               , 'fp
               , ( 'e Scalar_challenge.t Bulletproof_challenge.t
                 , Backend.Tick.Rounds.n )
                 Vector.vec
               , 'g )
               Stable.Latest.t
             , ( ( 'd
                 , 'b Scalar_challenge.t
                 , 'a
                 , 'a option
                 , 'b Scalar_challenge.t Plonk.In_circuit.Lookup.t option
                 , bool )
                 Plonk.In_circuit.t
               , 'b Scalar_challenge.t
               , 'a
               , ( 'b Scalar_challenge.t Bulletproof_challenge.t
                 , Backend.Tick.Rounds.n )
                 Vector.vec
               , 'h )
               Stable.Latest.t
             , 'f )
             Snarky_backendless.Typ.t
      end

      val to_minimal :
           ('a, 'b, 'c, _, 'd, 'e, 'f, 'bool) In_circuit.t
        -> to_option:('d -> 'b Plonk.In_circuit.Lookup.t option)
        -> ('a, 'b, 'c, 'bool, 'e, 'f) Minimal.t
    end

    module Stable : sig
      module V1 : sig
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
        [@@deriving
          sexp, compare, yojson, hlist, hash, equal, bin_shape, bin_io]

        include Pickles_types.Sigs.VERSIONED
      end

      module Latest = V1
    end

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
          Stable.Latest.t =
      { deferred_values :
          ('plonk, 'scalar_challenge, 'fp, 'bp_chals, 'index) Deferred_values.t
      ; sponge_digest_before_evaluations : 'digest
      ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
      }
    [@@deriving sexp, compare, yojson, hlist, hash, equal]

    (** The component of the proof accumulation state that is only computed on
        by the "wrapping" proof system, and that can be handled opaquely by any
        "step" circuits. *)
    module Messages_for_next_wrap_proof : sig
      module Stable : sig
        module V1 : sig
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
          [@@deriving
            sexp, compare, yojson, hlist, hash, equal, bin_shape, bin_io]

          include Pickles_types.Sigs.VERSIONED
        end

        module Latest = V1
      end

      type ('g1, 'bulletproof_challenges) t =
            ('g1, 'bulletproof_challenges) Stable.Latest.t =
        { challenge_polynomial_commitment : 'g1
        ; old_bulletproof_challenges : 'bulletproof_challenges
        }
      [@@deriving sexp, compare, yojson, hlist, hash, equal]

      val to_field_elements :
           ('g, (('f, 'a) Vector.t, 'b) Vector.t) t
        -> g1:('g -> 'f list)
        -> 'f Core_kernel.Array.t

      val typ :
           ( 'a
           , 'b
           , 'c
           , (unit, 'c) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
           )
           snarky_typ
        -> ('d, 'e, 'c) Snarky_backendless.Typ.t
        -> length:'f Nat.nat
        -> ( ('a, ('d, 'f) Vector.vec) t
           , ('b, ('e, 'f) Vector.vec) t
           , 'c )
           Snarky_backendless.Typ.t
    end

    module Minimal : sig
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

    module In_circuit : sig
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

      val typ :
           (module Snarky_backendless.Snark_intf.Run with type field = 'f)
        -> dummy_scalar:'a
        -> dummy_scalar_challenge:'b Scalar_challenge.t
        -> challenge:
             ( 'c
             , 'd
             , 'f
             , ( unit
               , 'f )
               Snarky_backendless.Checked_runner.Simple.Types.Checked.t )
             snarky_typ
        -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
        -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
        -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
        -> ( 'g
           , 'h
           , 'f
           , (unit, 'f) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
           )
           snarky_typ
        -> ( 'i
           , 'j
           , 'f
           , (unit, 'f) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
           )
           snarky_typ
        -> ( 'k
           , 'l
           , 'f
           , (unit, 'f) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
           )
           snarky_typ
        -> ( ( ( 'c
               , 'e Scalar_challenge.t
               , 'fp
               , ('fp, 'boolean) Plonk_types.Opt.t
               , ( 'e Scalar_challenge.t
                   Deferred_values.Plonk.In_circuit.Lookup.t
                 , 'boolean )
                 Plonk_types.Opt.t
               , ('f Snarky_backendless.Cvar.t
                  Snarky_backendless__Snark_intf.Boolean0.t
                  as
                  'boolean ) )
               Deferred_values.Plonk.In_circuit.t
             , 'e Scalar_challenge.t
             , 'fp
             , 'g
             , 'i
             , ( 'e Scalar_challenge.t Bulletproof_challenge.t
               , Backend.Tick.Rounds.n )
               Vector.vec
             , 'k )
             Stable.Latest.t
           , ( ( 'd
               , 'b Scalar_challenge.t
               , 'a
               , 'a option
               , 'b Scalar_challenge.t Deferred_values.Plonk.In_circuit.Lookup.t
                 option
               , bool )
               Deferred_values.Plonk.In_circuit.t
             , 'b Scalar_challenge.t
             , 'a
             , 'h
             , 'j
             , ( 'b Scalar_challenge.t Bulletproof_challenge.t
               , Backend.Tick.Rounds.n )
               Vector.vec
             , 'l )
             Stable.Latest.t
           , 'f )
           Snarky_backendless.Typ.t
    end

    val to_minimal :
         ('a, 'b, 'c, _, 'd, 'bool, 'e, 'f, 'g, 'h) In_circuit.t
      -> to_option:('d -> 'b Deferred_values.Plonk.In_circuit.Lookup.t option)
      -> ('a, 'b, 'c, 'bool, 'e, 'f, 'g, 'h) Minimal.t
  end

  (** The component of the proof accumulation state that is only computed on by
      the "stepping" proof system, and that can be handled opaquely by any
      "wrap" circuits. *)
  module Messages_for_next_step_proof : sig
    type ('g, 's, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
      { app_state : 's
            (** The actual application-level state (e.g., for Mina, this is the
                protocol state which contains the merkle root of the ledger,
                state related to consensus, etc.) *)
      ; dlog_plonk_index : 'g Plonk_verification_key_evals.t
            (** The verification key corresponding to the wrap-circuit for this
                recursive proof system.  It gets threaded through all the
                circuits so that the step circuits can verify proofs against
                it.  *)
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }
    [@@deriving sexp, hlist]

    val to_field_elements :
         ('a, 'b, ('g, 'c) Vector.t, (('f, 'd) Vector.t, 'c) Vector.t) t
      -> app_state:('b -> 'f Core_kernel.Array.t)
      -> comm:('a -> 'f Core_kernel.Array.t)
      -> g:('g -> 'f list)
      -> 'f Core_kernel.Array.t

    val to_field_elements_without_index :
         ('a, 'b, ('g, 'c) Vector.t, (('f, 'd) Vector.t, 'c) Vector.t) t
      -> app_state:('b -> 'f Core_kernel.Array.t)
      -> g:('g -> 'f list)
      -> 'f Core_kernel.Array.t

    val typ :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> ('d, 'e, 'c) Snarky_backendless.Typ.t
      -> ( 'f
         , 'g
         , 'c
         , (unit, 'c) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
         )
         snarky_typ
      -> ( 'h
         , 'i
         , 'c
         , (unit, 'c) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
         )
         snarky_typ
      -> 'j Nat.nat
      -> ( ('a, 'f, ('d, 'j) Vector.vec, 'h) t
         , ('b, 'g, ('e, 'j) Vector.vec, 'i) t
         , 'c )
         Snarky_backendless.Typ.t
  end

  module Lookup_parameters : sig
    type ('chal, 'chal_var, 'fp, 'fp_var) t =
      { zero : ('chal, 'chal_var, 'fp, 'fp_var) Zero_values.t
      ; use : Plonk_types.Opt.Flag.t
      }

    val opt_spec :
         'f Spec.impl
      -> ('a, 'b, 'c, 'd) t
      -> ( ('a Scalar_challenge.t * unit) Hlist.HlistId.t option
         , ( ('b Scalar_challenge.t * unit) Hlist.HlistId.t
           , 'f Snarky_backendless.Cvar.t
             Snarky_backendless__Snark_intf.Boolean0.t )
           opt
         , < bool1 : bool
           ; bool2 :
               'f Snarky_backendless.Cvar.t
               Snarky_backendless__Snark_intf.Boolean0.t
           ; challenge1 : 'a
           ; challenge2 : 'b
           ; field1 : 'c
           ; field2 : 'd
           ; .. > )
         Spec.T.t
  end

  (** This is the full statement for "wrap" proofs which contains
      - the application-level statement (app_state)
      - data needed to perform the final verification of the proof, which correspond
        to parts of incompletely verified proofs.
  *)
  module Statement : sig
    module Stable : sig
      module V1 : sig
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
        [@@deriving compare, yojson, sexp, hash, equal, bin_shape, bin_io]

        include Pickles_types.Sigs.VERSIONED
      end

      module Latest = V1
    end

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
          Stable.Latest.t =
      { proof_state :
          ( 'plonk
          , 'scalar_challenge
          , 'fp
          , 'messages_for_next_wrap_proof
          , 'digest
          , 'bp_chals
          , 'index )
          Proof_state.t
      ; messages_for_next_step_proof : 'messages_for_next_step_proof
      }
    [@@deriving compare, yojson, sexp, hash, equal]

    module Minimal : sig
      module Stable : sig
        module V1 : sig
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
          [@@deriving compare, yojson, sexp, hash, equal, bin_shape, bin_io]

          include Pickles_types.Sigs.VERSIONED
        end

        module Latest = V1
      end

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
        Stable.Latest.t
      [@@deriving compare, yojson, sexp, hash, equal]
    end

    module In_circuit : sig
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

      type 'a vec8 :=
        ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
        Hlist.HlistId.t

      type ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'fp_opt, 'bool) flat_repr :=
        ( ('a, Nat.N5.n) Vector.t
        * ( ('b, Nat.N2.n) Vector.t
          * ( ('c, Nat.N3.n) Vector.t
            * ( ('d, Nat.N3.n) Vector.t
              * ('e * (('f, Nat.N1.n) Vector.t * ('bool vec8 * ('g * unit)))) )
            ) ) )
        Hlist.HlistId.t

      (** A layout of the raw data in a statement, which is needed for
          representing it inside the circuit. *)
      val spec :
           'a Spec.impl
        -> ( 'challenge1
           , 'challenge2
           , 'field1 Hlist0.Id.t
           , 'field2 Hlist0.Id.t )
           Lookup_parameters.t
        -> Plonk_types.Opt.Flag.t Plonk_types.Features.t
        -> ( ( 'field1
             , 'challenge1
             , 'challenge1 Scalar_challenge.t
             , 'digest1
             , ('bulletproof_challenge1, Backend.Tick.Rounds.n) Vector.t
             , 'branch_data1
             , ('challenge1 Scalar_challenge.t * unit) Hlist.HlistId.t option
             , 'field1 option
             , bool )
             flat_repr
           , ( 'field2
             , 'challenge2
             , 'challenge2 Scalar_challenge.t
             , 'digest2
             , ('bulletproof_challenge2, Backend.Tick.Rounds.n) Vector.t
             , 'branch_data2
             , ( ('challenge2 Scalar_challenge.t * unit) Hlist.HlistId.t
               , 'bool2 )
               opt
             , 'field2 option
             , 'bool2 )
             flat_repr
           , < bool1 : bool
             ; bool2 :
                 ('a Snarky_backendless.Cvar.t
                  Snarky_backendless__Snark_intf.Boolean0.t
                  as
                  'bool2 )
             ; branch_data1 : 'branch_data1
             ; branch_data2 : 'branch_data2
             ; bulletproof_challenge1 : 'bulletproof_challenge1
             ; bulletproof_challenge2 : 'bulletproof_challenge2
             ; challenge1 : 'challenge1
             ; challenge2 : 'challenge2
             ; digest1 : 'digest1
             ; digest2 : 'digest2
             ; field1 : 'field1
             ; field2 : 'field2
             ; .. > )
           Spec.T.t

      (** Convert a statement (as structured data) into the flat data-based representation. *)
      val to_data :
           ('a, 'b, 'c, 'fp_opt, 'd, 'bool, 'e, 'e, 'e, 'f, 'g) t
        -> option_map:
             (   'd
              -> f:
                   (   'h Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
                    -> ('h * unit) Hlist.HlistId.t )
              -> 'j Hlist0.Id.t )
        -> to_opt:('fp_opt -> 'fp_opt2)
        -> ('c, 'a, 'b, 'e, 'f, 'g, 'j, 'fp_opt2, 'bool) flat_repr

      (** Construct a statement (as structured data) from the flat data-based representation. *)
      val of_data :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'fp option, 'bool) flat_repr
        -> feature_flags:
             Pickles_types.Plonk_types.Opt.Flag.t
             Pickles_types.Plonk_types.Features.t
        -> option_map:
             (   'g Hlist0.Id.t
              -> f:
                   (   ('h * unit) Hlist.HlistId.t
                    -> 'h Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
                   )
              -> 'j )
        -> of_opt:(('fp, 'bool) Pickles_types.Plonk_types.Opt.t -> 'fp_opt2)
        -> ('b, 'c, 'a, 'fp_opt2, 'j, 'bool, 'd, 'd, 'd, 'e, 'f) t
    end

    val to_minimal :
         ('a, 'b, 'c, _, 'd, 'bool, 'e, 'f, 'g, 'h, 'i) In_circuit.t
      -> to_option:
           (   'd
            -> 'b Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t option
           )
      -> ('a, 'b, 'c, 'bool, 'e, 'f, 'g, 'h, 'i) Minimal.t
  end
end

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
    module Deferred_values : sig
      module Plonk : sig
        module Minimal : sig
          (** Challenges from the PLONK IOP. These, plus the evaluations
              that are already in the proof, are all that's needed to derive
              all the values in the {!module:In_circuit} version below.

              See src/lib/pickles/plonk_checks/plonk_checks.ml for the
              computation of the {!module:In_circuit} value from the
              {!module:Minimal} value. *)
          type ('challenge, 'scalar_challenge) t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal]

          val to_wrap :
               feature_flags:'bool Plonk_types.Features.t
            -> ('challenge, 'scalar_challenge) t
            -> ( 'challenge
               , 'scalar_challenge
               , 'bool )
               Wrap.Proof_state.Deferred_values.Plonk.Minimal.t

          val of_wrap :
               ( 'challenge
               , 'scalar_challenge
               , 'bool )
               Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
            -> ('challenge, 'scalar_challenge) t
        end

        module In_circuit : sig
          (** All scalar values deferred by a verifier circuit.

              The values in [vbmul], [complete_add], [endomul],
              [endomul_scalar], [perm], and are all scalars which will have
              been used to scale selector polynomials during the computation of
              the linearized polynomial commitment.

              Then, we expose them so the next guy (who can do scalar
              arithmetic) can check that they were computed correctly from the
              evaluations in the proof and the challenges.  *)
          type ('challenge, 'scalar_challenge, 'fp) t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
            ; zeta_to_srs_length : 'fp
            ; zeta_to_domain_size : 'fp
            ; perm : 'fp
                  (** scalar used on one of the permutation polynomial commitments. *)
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

          val to_wrap :
               opt_none:'lookup_opt
            -> false_:'bool
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fp_opt
               , 'lookup_opt
               , 'bool )
               Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t

          val of_wrap :
               assert_none:('lookup_opt -> unit)
            -> assert_false:('bool -> unit)
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fp_opt
               , 'lookup_opt
               , 'bool )
               Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
            -> ('challenge, 'scalar_challenge, 'fp) t

          val map_challenges :
               ('a, 'b, 'c) t
            -> f:('a -> 'f)
            -> scalar:('b -> 'g)
            -> ('f, 'g, 'c) t

          val map_fields : ('a, 'b, 'c) t -> f:('c -> 'f) -> ('a, 'b, 'f) t

          val typ :
               'f Spec.impl
            -> dummy_scalar:'a
            -> dummy_scalar_challenge:'b Scalar_challenge.t
            -> challenge:
                 ( 'c
                 , 'd
                 , 'f
                 , ( unit
                   , 'f )
                   Snarky_backendless.Checked_runner.Simple.Types.Checked.t )
                 Snarky_backendless.Types.Typ.t
            -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
            -> bool:
                 ( ('f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
                    as
                    'boolean )
                 , bool
                 , 'f )
                 Snarky_backendless.Typ.t
            -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
            -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
            -> ( ('c, 'e Scalar_challenge.t, 'fp) t
               , ('d, 'b Scalar_challenge.t, 'a) t
               , 'f )
               Snarky_backendless.Typ.t
        end

        val to_minimal :
             ('challenge, 'scalar_challenge, 'fp) In_circuit.t
          -> ('challenge, 'scalar_challenge) Minimal.t
      end

      (** All the scalar-field values needed to finalize the verification of a
          proof by checking that the correct values were used in the "group
          operations" part of the verifier.

          Consists of some evaluations of PLONK polynomials (columns,
          permutation aggregation, etc.)  and the remainder are things related
          to the inner product argument.
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

      module Minimal : sig
        type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
          ( ('challenge, 'scalar_challenge) Plonk.Minimal.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges )
          t_
        [@@deriving sexp, compare, yojson]
      end

      module In_circuit : sig
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

    module Per_proof : sig
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

      module Minimal : sig
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

      module In_circuit : sig
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

        type 'a vec8 :=
          ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
          Hlist.HlistId.t

        type ( 'field
             , 'digest
             , 'challenge
             , 'bulletproof_challenge
             , 'bool
             , 'optional
             , 'fp_opt
             , 'num_bulletproof_challenges )
             flat_repr :=
          ( ('field, Nat.N5.n) Vector.t
          * ( ('digest, Nat.N1.n) Vector.t
            * ( ('challenge, Nat.N2.n) Vector.t
              * ( ('challenge Scalar_challenge.t, Nat.N3.n) Vector.t
                * ( ( 'bulletproof_challenge
                    , 'num_bulletproof_challenges )
                    Vector.t
                  * (('bool, Nat.N1.n) Vector.t * unit) ) ) ) ) )
          Hlist.HlistId.t

        (** A layout of the raw data in this value, which is needed for
          representing it inside the circuit. *)
        val spec :
             'num_bulletproof_challenges Nat.t
          -> ( ( 'field1
               , 'digest1
               , 'challenge1
               , 'bulletproof_challenge1
               , bool
               , ('challenge1 Scalar_challenge.t * unit) Hlist.HlistId.t option
               , 'field1 option
               , 'num_bulletproof_challenges )
               flat_repr
             , ( 'field2
               , 'digest2
               , 'challenge2
               , 'bulletproof_challenge2
               , 'field2 Snarky_backendless__Snark_intf.Boolean0.t
               , ( ('challenge2 Scalar_challenge.t * unit) Hlist.HlistId.t
                 , 'field2 Snarky_backendless__Snark_intf.Boolean0.t )
                 Plonk_types.Opt.t
               , 'field2 option
               , 'num_bulletproof_challenges )
               flat_repr
             , < bool1 : bool
               ; bool2 : 'field2 Snarky_backendless__Snark_intf.Boolean0.t
               ; bulletproof_challenge1 : 'bulletproof_challenge1
               ; bulletproof_challenge2 : 'bulletproof_challenge2
               ; challenge1 : 'challenge1
               ; challenge2 : 'challenge2
               ; digest1 : 'digest1
               ; digest2 : 'digest2
               ; field1 : 'field1
               ; field2 : ('f Snarky_backendless.Cvar.t as 'field2)
               ; .. > )
             Spec.T.t

        val to_data :
             ('a, 'b, 'c, 'e, 'f, 'g) t
          -> ( ('c, Nat.N5.n) Vector.t
             * ( ('f, Nat.N1.n) Vector.t
               * ( ('a, Nat.N2.n) Vector.t
                 * ( ('b, Nat.N3.n) Vector.t
                   * ('e * (('g, Nat.N1.n) Vector.t * unit)) ) ) ) )
             Hlist.HlistId.t

        val of_data :
             ( ('a, Nat.N5.n) Vector.t
             * ( ('b, Nat.N1.n) Vector.t
               * ( ('c, Nat.N2.n) Vector.t
                 * ( ('d, Nat.N3.n) Vector.t
                   * ('e * (('f, Nat.N1.n) Vector.t * unit)) ) ) ) )
             Hlist.HlistId.t
          -> ('c, 'd, 'a, 'e, 'b, 'f) t
      end

      val typ :
           'a Spec.impl
        -> ( 'b
           , 'c
           , 'a
           , (unit, 'a) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
           )
           snarky_typ
        -> assert_16_bits:('a Snarky_backendless.Cvar.t -> unit)
        -> zero:
             ( Limb_vector.Challenge.Constant.t
             , 'a Limb_vector.Challenge.t
             , 'c Hlist0.Id.t
             , 'b Hlist0.Id.t )
             Zero_values.t
        -> ( ( 'a Limb_vector.Challenge.t
             , 'a Limb_vector.Challenge.t Scalar_challenge.t
             , 'b
             , ( 'a Limb_vector.Challenge.t Scalar_challenge.t
                 Bulletproof_challenge.t
               , Backend.Tock.Rounds.n )
               Vector.t
               Hlist0.Id.t
             , 'a Snarky_backendless.Cvar.t
             , 'a Snarky_backendless.Cvar.t
               Snarky_backendless__Snark_intf.Boolean0.t )
             In_circuit.t
           , ( Limb_vector.Challenge.Constant.t
             , Limb_vector.Challenge.Constant.t Scalar_challenge.t
             , 'c
             , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                 Bulletproof_challenge.t
               , Backend.Tock.Rounds.n )
               Vector.t
               Hlist0.Id.t
             , (Limb_vector.Constant.Hex64.t, Digest.Limbs.n) Vector.t
             , bool )
             In_circuit.t
           , 'a )
           Snarky_backendless.Typ.t
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

    val spec :
         ('a, 'b, 'c) Spec.T.t
      -> ('d, 'e, 'c) Spec.T.t
      -> ( ('a * ('d * unit)) Hlist.HlistId.t
         , ('b * ('e * unit)) Hlist.HlistId.t
         , 'c )
         Spec.T.t

    type 'a vec8 :=
      ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit)))))))))
      Hlist.HlistId.t

    val typ :
         'f Spec.impl
      -> ( Limb_vector.Challenge.Constant.t
         , 'f Limb_vector.Challenge.t
         , 'a Hlist0.Id.t
         , 'b Hlist0.Id.t )
         Zero_values.t
      -> assert_16_bits:('f Snarky_backendless.Cvar.t -> unit)
      -> (Plonk_types.Opt.Flag.t Plonk_types.Features.t, 'n) Vector.t
      -> ( 'b
         , 'a
         , 'f
         , (unit, 'f) Snarky_backendless.Checked_runner.Simple.Types.Checked.t
         )
         snarky_typ
      -> ( ( ( ( 'f Limb_vector.Challenge.t
               , 'f Limb_vector.Challenge.t Scalar_challenge.t
               , 'b
               , ( 'f Limb_vector.Challenge.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Backend.Tock.Rounds.n )
                 Vector.t
                 Hlist0.Id.t
               , 'f Snarky_backendless.Cvar.t
               , 'f Snarky_backendless.Cvar.t
                 Snarky_backendless__Snark_intf.Boolean0.t )
               Per_proof.In_circuit.t
             , 'n )
             Vector.t
           , 'f Snarky_backendless.Cvar.t )
           t
         , ( ( ( Limb_vector.Challenge.Constant.t
               , Limb_vector.Challenge.Constant.t Scalar_challenge.t
               , 'a
               , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Backend.Tock.Rounds.n )
                 Vector.t
                 Hlist0.Id.t
               , (Limb_vector.Constant.Hex64.t, Digest.Limbs.n) Vector.t
               , bool )
               Per_proof.In_circuit.t
             , 'n )
             Vector.t
           , (Limb_vector.Constant.Hex64.t, Digest.Limbs.n) Vector.t )
           t
         , 'f )
         Snarky_backendless.Typ.t
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

    type 'a vec8 :=
      ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
      Hlist.HlistId.t

    val to_data :
         ( ( ( 'a
             , 'b
             , 'c
             , 'e Hlist0.Id.t
             , 'f
             , 'g )
             Proof_state.Per_proof.In_circuit.t
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
      -> ( ( ( 'c
             , 'd
             , 'a
             , 'e Hlist0.Id.t
             , 'b
             , 'f )
             Proof_state.Per_proof.In_circuit.t
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
                     * ( ('k, 'c) Vector.t
                       * ( ( 'a Snarky_backendless.Cvar.t
                             Snarky_backendless__Snark_intf.Boolean0.t
                           , Nat.N1.n )
                           Vector.t
                         * unit ) ) ) ) ) )
               Hlist.HlistId.t
             , 'b )
             Vector.t
           * ('j * (('j, 'b) Vector.t * unit)) )
           Hlist.HlistId.t
         , < bool1 : bool
           ; bool2 :
               'a Snarky_backendless.Cvar.t
               Snarky_backendless__Snark_intf.Boolean0.t
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
  type 'n t =
    (Backend.Tock.Field.t Snarky_backendless.Cvar.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant : sig
    type 'n t = (Backend.Tock.Field.t Wrap_bp_vec.t, 'n) Vector.t
  end
end

(** Alias for
 ** {!val:Pickles_base.Side_loaded_verification_key.index_to_field_elements} *)
val index_to_field_elements :
  'a Plonk_verification_key_evals.t -> g:('a -> 'b array) -> 'b array
