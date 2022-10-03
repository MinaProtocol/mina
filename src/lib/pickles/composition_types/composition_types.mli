(* Composition types *)

module Opt = Pickles_types.Plonk_types.Opt

type ('a, 'b) opt := ('a, 'b) Opt.t

type ('var, 'value, 'field, 'checked) snarky_typ :=
  ('var, 'value, 'field, 'checked) Snarky_backendless.Types.Typ.t

(** {2 Module aliases} *)

module Digest = Digest
module Spec = Spec
module Branch_data = Branch_data
module Bulletproof_challenge = Bulletproof_challenge
module Nvector = Pickles_types.Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge

(** {2 Modules} *)

(** *)
module Zero_values : sig
  type ('chal, 'fp) single = { challenge : 'chal; scalar : 'fp }

  type ('chal, 'chal_var, 'fp, 'fp_var) t =
    { value : ('chal, 'fp) single; var : ('chal_var, 'fp_var) single }
end

(** *)
module Wrap : sig
  module Proof_state : sig
    module Deferred_values : sig
      module Plonk : sig
        (** *)
        module Minimal : sig
          module Stable : sig
            module V1 : sig
              type ('challenge, 'scalar_challenge) t =
                    ( 'challenge
                    , 'scalar_challenge )
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
                }
              [@@deriving sexp, compare, yojson, hlist, hash, equal]

              include
                Pickles_types.Sigs.Binable.S2 with type ('a, 'b) t := ('a, 'b) t

              include Pickles_types.Sigs.VERSIONED

              val to_latest : 'a -> 'a
            end

            module Latest = V1
          end

          type ('challenge, 'scalar_challenge) t =
                ('challenge, 'scalar_challenge) Stable.Latest.t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
            ; joint_combiner : 'scalar_challenge option
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal]
        end

        module Generic_coeffs_vec :
            module type of
              Pickles_types.Vector.With_length (Pickles_types.Nat.N9)

        module In_circuit : sig
          module Lookup : sig
            type ('scalar_challenge, 'fp) t =
              { joint_combiner : 'scalar_challenge; lookup_gate : 'fp }
            [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

            val to_struct :
                 ('a Pickles_types.Hlist0.Id.t, 'b Pickles_types.Hlist0.Id.t) t
              -> ('a * ('b * unit)) Pickles_types.Hlist.HlistId.t

            val of_struct :
                 ('a * ('b * unit)) Pickles_types.Hlist.HlistId.t
              -> ('a Pickles_types.Hlist0.Id.t, 'b Pickles_types.Hlist0.Id.t) t

            val typ :
                 ( 'a
                 , 'b
                 , 'f
                 , (unit, 'f) Snarky_backendless.Checked_ast.t )
                 Snarky_backendless.Types.Typ.t
              -> ('fp, 'c, 'f) Snarky_backendless.Typ.t
              -> (('a, 'fp) t, ('b, 'c) t, 'f) Snarky_backendless.Typ.t
          end

          type ('challenge, 'scalar_challenge, 'fp, 'lookup_opt) t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
            ; zeta_to_srs_length : 'fp
            ; zeta_to_domain_size : 'fp
            ; poseidon_selector : 'fp
            ; vbmul : 'fp
            ; complete_add : 'fp
            ; endomul : 'fp
            ; endomul_scalar : 'fp
            ; perm : 'fp
            ; generic : 'fp Generic_coeffs_vec.t
            ; lookup : 'lookup_opt
            }
          [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

          val map_challenges :
               ('a, 'b, 'c, (('b, 'd) Lookup.t, 'e) Opt.t) t
            -> f:('a -> 'f)
            -> scalar:('b -> 'g)
            -> ('f, 'g, 'c, (('g, 'd) Lookup.t, 'e) Opt.t) t

          val map_fields :
               ('a, 'b, 'c, (('d, 'c) Lookup.t, 'e) Opt.t) t
            -> f:('c -> 'f)
            -> ('a, 'b, 'f, (('d, 'f) Lookup.t, 'e) Opt.t) t

          val typ :
               'f Spec.impl
            -> lookup:Pickles_types.Plonk_types.Opt.Flag.t
            -> dummy_scalar:'a
            -> dummy_scalar_challenge:'b Scalar_challenge.t
            -> challenge:
                 ( 'c
                 , 'd
                 , 'f
                 , (unit, 'f) Snarky_backendless.Checked_ast.t )
                 Snarky_backendless.Types.Typ.t
            -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
            -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
            -> ( ( 'c
                 , 'e Scalar_challenge.t
                 , 'fp
                 , ( ('e Scalar_challenge.t, 'fp) Lookup.t
                   , 'f Snarky_backendless.Cvar.t
                     Snarky_backendless__Snark_intf.Boolean0.t )
                   Pickles_types.Plonk_types.Opt.t )
                 t
               , ( 'd
                 , 'b Scalar_challenge.t
                 , 'a
                 , ('b Scalar_challenge.t, 'a) Lookup.t option )
                 t
               , 'f )
               Snarky_backendless.Typ.t
        end

        val to_minimal :
             ('challenge, 'scalar_challenge, 'fp, 'lookup_opt) In_circuit.t
          -> to_option:
               (   'lookup_opt
                -> ('scalar_challenge, 'fp) In_circuit.Lookup.t option )
          -> ('challenge, 'scalar_challenge) Minimal.t
      end

      module Stable : sig
        module V1 : sig
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
            ; b : 'fp
            ; xi : 'scalar_challenge
            ; bulletproof_challenges : 'bulletproof_challenges
            ; branch_data : 'branch_data
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
             , 'bulletproof_challenges
             , 'index )
             t =
          ( ('challenge, 'scalar_challenge) Plonk.Minimal.t
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
             , 'lookup_opt
             , 'bulletproof_challenges
             , 'branch_data )
             t =
          ( ('challenge, 'scalar_challenge, 'fp, 'lookup_opt) Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fp
          , 'bulletproof_challenges
          , 'branch_data )
          Stable.Latest.t
        [@@deriving sexp, compare, yojson, hash, equal]

        val typ :
             (module Snarky_backendless.Snark_intf.Run with type field = 'f)
          -> lookup:Pickles_types.Plonk_types.Opt.Flag.t
          -> dummy_scalar:'a
          -> dummy_scalar_challenge:'b Scalar_challenge.t
          -> challenge:
               ( 'c
               , 'd
               , 'f
               , (unit, 'f) Snarky_backendless.Checked_ast.t )
               snarky_typ
          -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
          -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
          -> ( 'g
             , 'h
             , 'f
             , (unit, 'f) Snarky_backendless.Checked_ast.t )
             snarky_typ
          -> ( ( ( 'c
                 , 'e Scalar_challenge.t
                 , 'fp
                 , ( ('e Scalar_challenge.t, 'fp) Plonk.In_circuit.Lookup.t
                   , 'f Snarky_backendless.Cvar.t
                     Snarky_backendless__Snark_intf.Boolean0.t )
                   Pickles_types.Plonk_types.Opt.t )
                 Plonk.In_circuit.t
               , 'e Scalar_challenge.t
               , 'fp
               , ( 'e Scalar_challenge.t Bulletproof_challenge.t
                 , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
                 Pickles_types.Vector.vec
               , 'g )
               Stable.Latest.t
             , ( ( 'd
                 , 'b Scalar_challenge.t
                 , 'a
                 , ('b Scalar_challenge.t, 'a) Plonk.In_circuit.Lookup.t option
                 )
                 Plonk.In_circuit.t
               , 'b Scalar_challenge.t
               , 'a
               , ( 'b Scalar_challenge.t Bulletproof_challenge.t
                 , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
                 Pickles_types.Vector.vec
               , 'h )
               Stable.Latest.t
             , 'f )
             Snarky_backendless.Typ.t
      end

      val to_minimal :
           ('a, 'b, 'c, 'd, 'e, 'f) In_circuit.t
        -> to_option:('d -> ('b, 'c) Plonk.In_circuit.Lookup.t option)
        -> ('a, 'b, 'c, 'e, 'f) Minimal.t
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
           ('g, (('f, 'a) Pickles_types.Vector.t, 'b) Pickles_types.Vector.t) t
        -> g1:('g -> 'f list)
        -> 'f Core_kernel.Array.t

      val typ :
           ('a, 'b, 'c, (unit, 'c) Snarky_backendless.Checked_ast.t) snarky_typ
        -> ('d, 'e, 'c) Snarky_backendless.Typ.t
        -> length:'f Pickles_types.Nat.nat
        -> ( ('a, ('d, 'f) Pickles_types.Vector.vec) t
           , ('b, ('e, 'f) Pickles_types.Vector.vec) t
           , 'c )
           Snarky_backendless.Typ.t
    end

    module Minimal : sig
      type ( 'challenge
           , 'scalar_challenge
           , 'scalar_challenge_opt
           , 'fp
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ('challenge, 'scalar_challenge) Deferred_values.Plonk.Minimal.t
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
           , 'lookup_opt
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'lookup_opt )
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
        -> lookup:Pickles_types.Plonk_types.Opt.Flag.t
        -> dummy_scalar:'a
        -> dummy_scalar_challenge:'b Scalar_challenge.t
        -> challenge:
             ( 'c
             , 'd
             , 'f
             , (unit, 'f) Snarky_backendless.Checked_ast.t )
             snarky_typ
        -> scalar_challenge:('e, 'b, 'f) Snarky_backendless.Typ.t
        -> ('fp, 'a, 'f) Snarky_backendless.Typ.t
        -> ('g, 'h, 'f, (unit, 'f) Snarky_backendless.Checked_ast.t) snarky_typ
        -> ('i, 'j, 'f, (unit, 'f) Snarky_backendless.Checked_ast.t) snarky_typ
        -> ('k, 'l, 'f, (unit, 'f) Snarky_backendless.Checked_ast.t) snarky_typ
        -> ( ( ( 'c
               , 'e Scalar_challenge.t
               , 'fp
               , ( ( 'e Scalar_challenge.t
                   , 'fp )
                   Deferred_values.Plonk.In_circuit.Lookup.t
                 , 'f Snarky_backendless.Cvar.t
                   Snarky_backendless__Snark_intf.Boolean0.t )
                 Pickles_types.Plonk_types.Opt.t )
               Deferred_values.Plonk.In_circuit.t
             , 'e Scalar_challenge.t
             , 'fp
             , 'g
             , 'i
             , ( 'e Scalar_challenge.t Bulletproof_challenge.t
               , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
               Pickles_types.Vector.vec
             , 'k )
             Stable.Latest.t
           , ( ( 'd
               , 'b Scalar_challenge.t
               , 'a
               , ( 'b Scalar_challenge.t
                 , 'a )
                 Deferred_values.Plonk.In_circuit.Lookup.t
                 option )
               Deferred_values.Plonk.In_circuit.t
             , 'b Scalar_challenge.t
             , 'a
             , 'h
             , 'j
             , ( 'b Scalar_challenge.t Bulletproof_challenge.t
               , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
               Pickles_types.Vector.vec
             , 'l )
             Stable.Latest.t
           , 'f )
           Snarky_backendless.Typ.t
    end

    val to_minimal :
         ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) In_circuit.t
      -> to_option:
           ('d -> ('b, 'c) Deferred_values.Plonk.In_circuit.Lookup.t option)
      -> ('a, 'b, 'i, 'c, 'e, 'f, 'g, 'h) Minimal.t
  end

  module Messages_for_next_step_proof : sig
    type ('g, 's, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
      { app_state : 's
      ; dlog_plonk_index : 'g Pickles_types.Plonk_verification_key_evals.t
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }
    [@@deriving sexp, hlist]

    val to_field_elements :
         ( 'a
         , 'b
         , ('g, 'c) Pickles_types.Vector.t
         , (('f, 'd) Pickles_types.Vector.t, 'c) Pickles_types.Vector.t )
         t
      -> app_state:('b -> 'f Core_kernel.Array.t)
      -> comm:('a -> 'f Core_kernel.Array.t)
      -> g:('g -> 'f list)
      -> 'f Core_kernel.Array.t

    val to_field_elements_without_index :
         ( 'a
         , 'b
         , ('g, 'c) Pickles_types.Vector.t
         , (('f, 'd) Pickles_types.Vector.t, 'c) Pickles_types.Vector.t )
         t
      -> app_state:('b -> 'f Core_kernel.Array.t)
      -> g:('g -> 'f list)
      -> 'f Core_kernel.Array.t

    val typ :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> ('d, 'e, 'c) Snarky_backendless.Typ.t
      -> ('f, 'g, 'c, (unit, 'c) Snarky_backendless.Checked_ast.t) snarky_typ
      -> ('h, 'i, 'c, (unit, 'c) Snarky_backendless.Checked_ast.t) snarky_typ
      -> 'j Pickles_types.Nat.nat
      -> ( ('a, 'f, ('d, 'j) Pickles_types.Vector.vec, 'h) t
         , ('b, 'g, ('e, 'j) Pickles_types.Vector.vec, 'i) t
         , 'c )
         Snarky_backendless.Typ.t
  end

  module Lookup_parameters : sig
    type ('chal, 'chal_var, 'fp, 'fp_var) t =
      { zero : ('chal, 'chal_var, 'fp, 'fp_var) Zero_values.t
      ; use : Pickles_types.Plonk_types.Opt.Flag.t
      }

    val opt_spec :
         'f Spec.impl
      -> ('a, 'b, 'c Pickles_types.Hlist0.Id.t, 'd Pickles_types.Hlist0.Id.t) t
      -> ( ('a Scalar_challenge.t * ('c * unit)) Pickles_types.Hlist.HlistId.t
           option
         , ( ('b Scalar_challenge.t * ('d * unit)) Pickles_types.Hlist.HlistId.t
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
               , 'messages_for_next_wrap_proof
               , 'digest
               , 'messages_for_next_step_proof
               , 'bp_chals
               , 'index )
               t =
            ( ( 'challenge
              , 'scalar_challenge )
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
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'messages_for_next_step_proof
           , 'bp_chals
           , 'index )
           t =
        ( 'challenge
        , 'scalar_challenge
        , 'fp
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
           , 'lookup_opt
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'messages_for_next_step_proof
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'lookup_opt )
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

      val spec :
           'a Spec.impl
        -> ( 'b
           , 'c
           , 'd Pickles_types.Hlist0.Id.t
           , 'e Pickles_types.Hlist0.Id.t )
           Lookup_parameters.t
        -> ( ( ( 'd
               , Pickles_types.Nat.z Pickles_types.Nat.N19.plus_n )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Nat.z Pickles_types.Nat.N2.plus_n )
                 Pickles_types.Vector.t
               * ( ( 'b Scalar_challenge.t
                   , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                   Pickles_types.Vector.t
                 * ( ( 'f
                     , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                     Pickles_types.Vector.t
                   * ( ( 'g
                       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
                       Pickles_types.Vector.t
                     * ( ( 'h
                         , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                         Pickles_types.Vector.t
                       * ( ('b Scalar_challenge.t * ('d * unit))
                           Pickles_types.Hlist.HlistId.t
                           option
                         * unit ) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , ( ( 'e
               , Pickles_types.Nat.z Pickles_types.Nat.N19.plus_n )
               Pickles_types.Vector.t
             * ( ( 'c
                 , Pickles_types.Nat.z Pickles_types.Nat.N2.plus_n )
                 Pickles_types.Vector.t
               * ( ( 'c Scalar_challenge.t
                   , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                   Pickles_types.Vector.t
                 * ( ( 'i
                     , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                     Pickles_types.Vector.t
                   * ( ( 'j
                       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
                       Pickles_types.Vector.t
                     * ( ( 'k
                         , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                         Pickles_types.Vector.t
                       * ( ( ('c Scalar_challenge.t * ('e * unit))
                             Pickles_types.Hlist.HlistId.t
                           , 'a Snarky_backendless.Cvar.t
                             Snarky_backendless__Snark_intf.Boolean0.t )
                           opt
                         * unit ) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , < bool1 : bool
             ; bool2 :
                 'a Snarky_backendless.Cvar.t
                 Snarky_backendless__Snark_intf.Boolean0.t
             ; branch_data1 : 'h
             ; branch_data2 : 'k
             ; bulletproof_challenge1 : 'g
             ; bulletproof_challenge2 : 'j
             ; challenge1 : 'b
             ; challenge2 : 'c
             ; digest1 : 'f
             ; digest2 : 'i
             ; field1 : 'd
             ; field2 : 'e
             ; .. > )
           Spec.T.t

      val to_data :
           ('a, 'b, 'c, 'd, 'e, 'e, 'e, 'f Pickles_types.Hlist0.Id.t, 'g) t
        -> option_map:
             (   'd
              -> f:
                   (   ( 'h Pickles_types.Hlist0.Id.t
                       , 'i Pickles_types.Hlist0.Id.t )
                       Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
                    -> ('h * ('i * unit)) Pickles_types.Hlist.HlistId.t )
              -> 'j Pickles_types.Hlist0.Id.t )
        -> ( ('c, Pickles_types.Nat.N19.n) Pickles_types.Vector.t
           * ( ('a, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
             * ( ('b, Pickles_types.Nat.N3.n) Pickles_types.Vector.t
               * ( ('e, Pickles_types.Nat.N3.n) Pickles_types.Vector.t
                 * ( 'f
                   * ( ('g, Pickles_types.Nat.N1.n) Pickles_types.Vector.t
                     * ('j * unit) ) ) ) ) ) )
           Pickles_types.Hlist.HlistId.t

      val of_data :
           ( ( 'a
             , Pickles_types.Nat.N9.n Pickles_types.Nat.s Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s
               Pickles_types.Nat.s )
             Pickles_types.Vector.t
           * ( ( 'b
               , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s )
               Pickles_types.Vector.t
             * ( ( 'c
                 , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                   Pickles_types.Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'd
                   , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                     Pickles_types.Nat.s )
                   Pickles_types.Vector.t
                 * ( 'e
                   * ( ( 'f
                       , Pickles_types.Nat.z Pickles_types.Nat.s )
                       Pickles_types.Vector.t
                     * ('g * unit) ) ) ) ) ) )
           Pickles_types.Hlist.HlistId.t
        -> option_map:
             (   'g Pickles_types.Hlist0.Id.t
              -> f:
                   (   ('h * ('i * unit)) Pickles_types.Hlist.HlistId.t
                    -> ( 'h Pickles_types.Hlist0.Id.t
                       , 'i Pickles_types.Hlist0.Id.t )
                       Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t )
              -> 'j )
        -> ('b, 'c, 'a, 'j, 'd, 'd, 'd, 'e Pickles_types.Hlist0.Id.t, 'f) t
    end

    val to_minimal :
         ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) In_circuit.t
      -> to_option:
           (   'd
            -> ('b, 'c) Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
               option )
      -> ('a, 'b, 'c, 'e, 'f, 'g, 'h, 'i) Minimal.t
  end
end

(** *)

module Step : sig
  module Plonk_polys = Pickles_types.Nat.N10

  module Bulletproof : sig
    include module type of Pickles_types.Plonk_types.Openings.Bulletproof

    module Advice : sig
      type 'fq t = { b : 'fq; combined_inner_product : 'fq } [@@deriving hlist]

      val to_hlist : 'fq t -> (unit, 'fq -> 'fq -> unit) H_list.t

      val of_hlist : (unit, 'fq -> 'fq -> unit) H_list.t -> 'fq t
    end
  end

  module Proof_state : sig
    module Deferred_values : sig
      module Plonk = Wrap.Proof_state.Deferred_values.Plonk

      type ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_ =
        { plonk : 'plonk
        ; combined_inner_product : 'fq
        ; xi : 'scalar_challenge
        ; bulletproof_challenges : 'bulletproof_challenges
        ; b : 'fq
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
        type ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bool
             , 'bulletproof_challenges )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fq
            , (('scalar_challenge, 'fq) Plonk.In_circuit.Lookup.t, 'bool) Opt.t
            )
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

    module Per_proof : sig
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
        ; should_finalize : 'bool
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
             , 'lookup_opt
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fq
            , 'lookup_opt )
            Deferred_values.Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges
          , 'digest
          , 'bool )
          t_
        [@@deriving sexp, compare, yojson]

        val spec :
             'a Spec.impl
          -> 'b Pickles_types.Nat.t
          -> ( 'c
             , 'd
             , 'e Pickles_types.Hlist0.Id.t
             , 'f Pickles_types.Hlist0.Id.t )
             Wrap.Lookup_parameters.t
          -> ( ( ( 'e
                 , Pickles_types.Nat.z Pickles_types.Nat.N19.plus_n )
                 Pickles_types.Vector.t
               * ( ( 'g
                   , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                   Pickles_types.Vector.t
                 * ( ( 'c
                     , Pickles_types.Nat.z Pickles_types.Nat.N2.plus_n )
                     Pickles_types.Vector.t
                   * ( ( 'c Scalar_challenge.t
                       , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                       Pickles_types.Vector.t
                     * ( ('h, 'b) Pickles_types.Vector.t
                       * ( ( bool
                           , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                           Pickles_types.Vector.t
                         * ( ('c Scalar_challenge.t * ('e * unit))
                             Pickles_types.Hlist.HlistId.t
                             option
                           * unit ) ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , ( ( 'f
                 , Pickles_types.Nat.z Pickles_types.Nat.N19.plus_n )
                 Pickles_types.Vector.t
               * ( ( 'i
                   , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Nat.z Pickles_types.Nat.N2.plus_n )
                     Pickles_types.Vector.t
                   * ( ( 'd Scalar_challenge.t
                       , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                       Pickles_types.Vector.t
                     * ( ('j, 'b) Pickles_types.Vector.t
                       * ( ( 'a Snarky_backendless.Cvar.t
                             Snarky_backendless__Snark_intf.Boolean0.t
                           , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                           Pickles_types.Vector.t
                         * ( ( ('d Scalar_challenge.t * ('f * unit))
                               Pickles_types.Hlist.HlistId.t
                             , 'a Snarky_backendless.Cvar.t
                               Snarky_backendless__Snark_intf.Boolean0.t )
                             Pickles_types.Plonk_types.Opt.t
                           * unit ) ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , < bool1 : bool
               ; bool2 :
                   'a Snarky_backendless.Cvar.t
                   Snarky_backendless__Snark_intf.Boolean0.t
               ; bulletproof_challenge1 : 'h
               ; bulletproof_challenge2 : 'j
               ; challenge1 : 'c
               ; challenge2 : 'd
               ; digest1 : 'g
               ; digest2 : 'i
               ; field1 : 'e
               ; field2 : 'f
               ; .. > )
             Spec.T.t

        val to_data :
             ('a, 'b, 'c, 'd, 'e Pickles_types.Hlist0.Id.t, 'f, 'g) t
          -> option_map:
               (   'd
                -> f:
                     (   ( 'h Pickles_types.Hlist0.Id.t
                         , 'i Pickles_types.Hlist0.Id.t )
                         Deferred_values.Plonk.In_circuit.Lookup.t
                      -> ('h * ('i * unit)) Pickles_types.Hlist.HlistId.t )
                -> 'j Pickles_types.Hlist0.Id.t )
          -> ( ( 'c
               , Pickles_types.Nat.N9.n Pickles_types.Nat.s Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s )
               Pickles_types.Vector.t
             * ( ( 'f
                 , Pickles_types.Nat.z Pickles_types.Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'a
                   , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                   )
                   Pickles_types.Vector.t
                 * ( ( 'b
                     , Pickles_types.Nat.z Pickles_types.Nat.s
                       Pickles_types.Nat.s
                       Pickles_types.Nat.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'g
                         , Pickles_types.Nat.z Pickles_types.Nat.s )
                         Pickles_types.Vector.t
                       * ('j * unit) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t

        val of_data :
             ( ( 'a
               , Pickles_types.Nat.N9.n Pickles_types.Nat.s Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Nat.z Pickles_types.Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                   )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Nat.z Pickles_types.Nat.s
                       Pickles_types.Nat.s
                       Pickles_types.Nat.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'f
                         , Pickles_types.Nat.z Pickles_types.Nat.s )
                         Pickles_types.Vector.t
                       * ('g * unit) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
          -> option_map:
               (   'g Pickles_types.Hlist0.Id.t
                -> f:
                     (   ('h * ('i * unit)) Pickles_types.Hlist.HlistId.t
                      -> ( 'h Pickles_types.Hlist0.Id.t
                         , 'i Pickles_types.Hlist0.Id.t )
                         Deferred_values.Plonk.In_circuit.Lookup.t )
                -> 'j )
          -> ('c, 'd, 'a, 'j, 'e Pickles_types.Hlist0.Id.t, 'b, 'f) t

        val map_lookup :
             ('a, 'b, 'c, 'd, 'e, 'f, 'g) t
          -> f:('d -> 'h)
          -> ( ('a, 'b, 'c, 'h) Deferred_values.Plonk.In_circuit.t
             , 'b
             , 'c
             , 'e
             , 'f
             , 'g )
             t_
      end

      val typ :
           'a Spec.impl
        -> ('b, 'c, 'a, (unit, 'a) Snarky_backendless.Checked_ast.t) snarky_typ
        -> assert_16_bits:('a Snarky_backendless.Cvar.t -> unit)
        -> zero:
             ( Limb_vector.Challenge.Constant.t
             , 'a Limb_vector.Challenge.t
             , 'c Pickles_types.Hlist0.Id.t
             , 'b Pickles_types.Hlist0.Id.t )
             Zero_values.t
        -> uses_lookup:Opt.Flag.t
        -> ( ( 'a Limb_vector.Challenge.t
             , 'a Limb_vector.Challenge.t Scalar_challenge.t
             , 'b
             , ( ( 'a Limb_vector.Challenge.t Scalar_challenge.t
                   Pickles_types.Hlist0.Id.t
                 , 'b Pickles_types.Hlist0.Id.t )
                 Deferred_values.Plonk.In_circuit.Lookup.t
               , 'a Snarky_backendless.Cvar.t
                 Snarky_backendless__Snark_intf.Boolean0.t )
               Opt.t
             , ( 'a Limb_vector.Challenge.t Scalar_challenge.t
                 Bulletproof_challenge.t
               , Pickles_types.Nat.z Backend.Tock.Rounds.plus_n )
               Pickles_types.Vector.t
               Pickles_types.Hlist0.Id.t
             , 'a Snarky_backendless.Cvar.t
             , 'a Snarky_backendless.Cvar.t
               Snarky_backendless__Snark_intf.Boolean0.t )
             In_circuit.t
           , ( Limb_vector.Challenge.Constant.t
             , Limb_vector.Challenge.Constant.t Scalar_challenge.t
             , 'c
             , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                 Pickles_types.Hlist0.Id.t
               , 'c Pickles_types.Hlist0.Id.t )
               Deferred_values.Plonk.In_circuit.Lookup.t
               option
             , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                 Bulletproof_challenge.t
               , Pickles_types.Nat.z Backend.Tock.Rounds.plus_n )
               Pickles_types.Vector.t
               Pickles_types.Hlist0.Id.t
             , ( Limb_vector.Constant.Hex64.t
               , Digest.Limbs.n )
               Pickles_types__Vector.vec
             , bool )
             In_circuit.t
           , 'a )
           Snarky_backendless.Typ.t
    end

    type ('unfinalized_proofs, 'messages_for_next_step_proof) t =
      { unfinalized_proofs : 'unfinalized_proofs
      ; messages_for_next_step_proof : 'messages_for_next_step_proof
      }
    [@@deriving sexp, compare, yojson, hlist]

    val spec :
         ('a, 'b, 'c) Spec.T.t
      -> ('d, 'e, 'c) Spec.T.t
      -> ( ('a * ('d * unit)) Pickles_types.Hlist.HlistId.t
         , ('b * ('e * unit)) Pickles_types.Hlist.HlistId.t
         , 'c )
         Spec.T.t

    val to_data :
         ( ( ( 'a
             , 'b
             , 'c
             , 'd
             , 'e Pickles_types.Hlist0.Id.t
             , 'f
             , 'g )
             Per_proof.In_circuit.t
           , 'h )
           Pickles_types.Vector.t
         , 'i Pickles_types.Hlist0.Id.t )
         t
      -> ( (    option_map:
                  (   'd
                   -> f:
                        (   ( 'j Pickles_types.Hlist0.Id.t
                            , 'k Pickles_types.Hlist0.Id.t )
                            Deferred_values.Plonk.In_circuit.Lookup.t
                         -> ('j * ('k * unit)) Pickles_types.Hlist.HlistId.t )
                   -> 'l Pickles_types.Hlist0.Id.t )
             -> ( ( 'c
                  , Pickles_types.Nat.N9.n Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s
                    Pickles_types.Nat.s )
                  Pickles_types.Vector.t
                * ( ( 'f
                    , Pickles_types.Nat.z Pickles_types.Nat.s )
                    Pickles_types.Vector.t
                  * ( ( 'a
                      , Pickles_types.Nat.z Pickles_types.Nat.s
                        Pickles_types.Nat.s )
                      Pickles_types.Vector.t
                    * ( ( 'b
                        , Pickles_types.Nat.z Pickles_types.Nat.s
                          Pickles_types.Nat.s
                          Pickles_types.Nat.s )
                        Pickles_types.Vector.t
                      * ( 'e
                        * ( ( 'g
                            , Pickles_types.Nat.z Pickles_types.Nat.s )
                            Pickles_types.Vector.t
                          * ('l * unit) ) ) ) ) ) )
                Pickles_types.Hlist.HlistId.t
           , 'h )
           Pickles_types.Vector.t
         * ('i * unit) )
         Pickles_types.Hlist.HlistId.t

    val of_data :
         ( ( ( ( 'a
               , Pickles_types.Nat.N9.n Pickles_types.Nat.s Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Nat.z Pickles_types.Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                   )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Nat.z Pickles_types.Nat.s
                       Pickles_types.Nat.s
                       Pickles_types.Nat.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'f
                         , Pickles_types.Nat.z Pickles_types.Nat.s )
                         Pickles_types.Vector.t
                       * ('g * unit) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'h )
           Pickles_types.Vector.t
         * ('i * unit) )
         Pickles_types.Hlist.HlistId.t
      -> ( (    option_map:
                  (   'g Pickles_types.Hlist0.Id.t
                   -> f:
                        (   ('j * ('k * unit)) Pickles_types.Hlist.HlistId.t
                         -> ( 'j Pickles_types.Hlist0.Id.t
                            , 'k Pickles_types.Hlist0.Id.t )
                            Deferred_values.Plonk.In_circuit.Lookup.t )
                   -> 'l )
             -> ( 'c
                , 'd
                , 'a
                , 'l
                , 'e Pickles_types.Hlist0.Id.t
                , 'b
                , 'f )
                Per_proof.In_circuit.t
           , 'h )
           Pickles_types.Vector.t
         , 'i Pickles_types.Hlist0.Id.t )
         t

    val typ :
         'f Spec.impl
      -> ( Limb_vector.Challenge.Constant.t
         , 'f Limb_vector.Challenge.t
         , 'a Pickles_types.Hlist0.Id.t
         , 'b Pickles_types.Hlist0.Id.t )
         Zero_values.t
      -> assert_16_bits:('f Snarky_backendless.Cvar.t -> unit)
      -> (Pickles_types.Plonk_types.Opt.Flag.t, 'n) Pickles_types.Vector.t
      -> ('b, 'a, 'f, (unit, 'f) Snarky_backendless.Checked_ast.t) snarky_typ
      -> ( ( ( ( 'f Limb_vector.Challenge.t
               , 'f Limb_vector.Challenge.t Scalar_challenge.t
               , 'b
               , ( ( 'f Limb_vector.Challenge.t Scalar_challenge.t
                     Pickles_types.Hlist0.Id.t
                   , 'b Pickles_types.Hlist0.Id.t )
                   Deferred_values.Plonk.In_circuit.Lookup.t
                 , 'f Snarky_backendless.Cvar.t
                   Snarky_backendless__Snark_intf.Boolean0.t )
                 Opt.t
               , ( 'f Limb_vector.Challenge.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Pickles_types.Nat.z Backend.Tock.Rounds.plus_n )
                 Pickles_types.Vector.t
                 Pickles_types.Hlist0.Id.t
               , 'f Snarky_backendless.Cvar.t
               , 'f Snarky_backendless.Cvar.t
                 Snarky_backendless__Snark_intf.Boolean0.t )
               Per_proof.In_circuit.t
             , 'n )
             Pickles_types.Vector.t
           , 'f Snarky_backendless.Cvar.t )
           t
         , ( ( ( Limb_vector.Challenge.Constant.t
               , Limb_vector.Challenge.Constant.t Scalar_challenge.t
               , 'a
               , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                   Pickles_types.Hlist0.Id.t
                 , 'a Pickles_types.Hlist0.Id.t )
                 Deferred_values.Plonk.In_circuit.Lookup.t
                 option
               , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Pickles_types.Nat.z Backend.Tock.Rounds.plus_n )
                 Pickles_types.Vector.t
                 Pickles_types.Hlist0.Id.t
               , ( Limb_vector.Constant.Hex64.t
                 , Digest.Limbs.n )
                 Pickles_types__Vector.vec
               , bool )
               Per_proof.In_circuit.t
             , 'n )
             Pickles_types.Vector.t
           , ( Limb_vector.Constant.Hex64.t
             , Digest.Limbs.n )
             Pickles_types__Vector.vec )
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

    val to_data :
         ( ( ( 'a
             , 'b
             , 'c
             , 'd
             , 'e Pickles_types.Hlist0.Id.t
             , 'f
             , 'g )
             Proof_state.Per_proof.In_circuit.t
           , 'h )
           Pickles_types.Vector.t
         , 'i Pickles_types.Hlist0.Id.t
         , 'j Pickles_types.Hlist0.Id.t )
         t
      -> option_map:
           (   'd
            -> f:
                 (   ( 'k Pickles_types.Hlist0.Id.t
                     , 'l Pickles_types.Hlist0.Id.t )
                     Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
                  -> ('k * ('l * unit)) Pickles_types.Hlist.HlistId.t )
            -> 'm Pickles_types.Hlist0.Id.t )
      -> ( ( ( ( 'c
               , Pickles_types.Nat.N9.n Pickles_types.Nat.s Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s )
               Pickles_types.Vector.t
             * ( ( 'f
                 , Pickles_types.Nat.z Pickles_types.Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'a
                   , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                   )
                   Pickles_types.Vector.t
                 * ( ( 'b
                     , Pickles_types.Nat.z Pickles_types.Nat.s
                       Pickles_types.Nat.s
                       Pickles_types.Nat.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'g
                         , Pickles_types.Nat.z Pickles_types.Nat.s )
                         Pickles_types.Vector.t
                       * ('m * unit) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'h )
           Pickles_types.Vector.t
         * ('i * ('j * unit)) )
         Pickles_types.Hlist.HlistId.t

    val of_data :
         ( ( ( ( 'a
               , Pickles_types.Nat.N9.n Pickles_types.Nat.s Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s
                 Pickles_types.Nat.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Nat.z Pickles_types.Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types.Nat.z Pickles_types.Nat.s Pickles_types.Nat.s
                   )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Nat.z Pickles_types.Nat.s
                       Pickles_types.Nat.s
                       Pickles_types.Nat.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'f
                         , Pickles_types.Nat.z Pickles_types.Nat.s )
                         Pickles_types.Vector.t
                       * ('g * unit) ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'h )
           Pickles_types.Vector.t
         * ('i * ('j * unit)) )
         Pickles_types.Hlist.HlistId.t
      -> option_map:
           (   'g Pickles_types.Hlist0.Id.t
            -> f:
                 (   ('k * ('l * unit)) Pickles_types.Hlist.HlistId.t
                  -> ( 'k Pickles_types.Hlist0.Id.t
                     , 'l Pickles_types.Hlist0.Id.t )
                     Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t )
            -> 'm )
      -> ( ( ( 'c
             , 'd
             , 'a
             , 'm
             , 'e Pickles_types.Hlist0.Id.t
             , 'b
             , 'f )
             Proof_state.Per_proof.In_circuit.t
           , 'h )
           Pickles_types.Vector.t
         , 'i Pickles_types.Hlist0.Id.t
         , 'j Pickles_types.Hlist0.Id.t )
         t

    val spec :
         'a Spec.impl
      -> 'b Pickles_types.Nat.t
      -> 'c Pickles_types.Nat.t
      -> ( 'd
         , 'e
         , 'f Pickles_types.Hlist0.Id.t
         , 'g Pickles_types.Hlist0.Id.t )
         Wrap.Lookup_parameters.t
      -> ( ( ( ( ( 'f
                 , Pickles_types.Nat.z Pickles_types.Nat.N19.plus_n )
                 Pickles_types.Vector.t
               * ( ( 'h
                   , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Nat.z Pickles_types.Nat.N2.plus_n )
                     Pickles_types.Vector.t
                   * ( ( 'd Scalar_challenge.t
                       , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                       Pickles_types.Vector.t
                     * ( ('i, 'c) Pickles_types.Vector.t
                       * ( ( bool
                           , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                           Pickles_types.Vector.t
                         * ( ('d Scalar_challenge.t * ('f * unit))
                             Pickles_types.Hlist.HlistId.t
                             option
                           * unit ) ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , 'b )
             Pickles_types.Vector.t
           * ('h * (('h, 'b) Pickles_types.Vector.t * unit)) )
           Pickles_types.Hlist.HlistId.t
         , ( ( ( ( 'g
                 , Pickles_types.Nat.z Pickles_types.Nat.N19.plus_n )
                 Pickles_types.Vector.t
               * ( ( 'j
                   , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                   Pickles_types.Vector.t
                 * ( ( 'e
                     , Pickles_types.Nat.z Pickles_types.Nat.N2.plus_n )
                     Pickles_types.Vector.t
                   * ( ( 'e Scalar_challenge.t
                       , Pickles_types.Nat.z Pickles_types.Nat.N3.plus_n )
                       Pickles_types.Vector.t
                     * ( ('k, 'c) Pickles_types.Vector.t
                       * ( ( 'a Snarky_backendless.Cvar.t
                             Snarky_backendless__Snark_intf.Boolean0.t
                           , Pickles_types.Nat.z Pickles_types.Nat.N1.plus_n )
                           Pickles_types.Vector.t
                         * ( ( ('e Scalar_challenge.t * ('g * unit))
                               Pickles_types.Hlist.HlistId.t
                             , 'a Snarky_backendless.Cvar.t
                               Snarky_backendless__Snark_intf.Boolean0.t )
                             Pickles_types.Plonk_types.Opt.t
                           * unit ) ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , 'b )
             Pickles_types.Vector.t
           * ('j * (('j, 'b) Pickles_types.Vector.t * unit)) )
           Pickles_types.Hlist.HlistId.t
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

(** *)
module Challenges_vector : sig
  type 'n t =
    ( Backend.Tock.Field.t Snarky_backendless.Cvar.t Wrap_bp_vec.t
    , 'n )
    Pickles_types.Vector.t

  module Constant : sig
    type 'n t = (Backend.Tock.Field.t Wrap_bp_vec.t, 'n) Pickles_types.Vector.t
  end
end
