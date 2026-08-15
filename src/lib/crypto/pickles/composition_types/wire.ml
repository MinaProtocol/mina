(** Wire-format polymorphic skeletons for {!Composition_types}.

    Each [Stable.V1] sub-module here is the type that the bin_io
    boundary serialises. The corresponding live in-memory records
    live in the sibling files (plonk_iop.ml, deferred_values.ml,
    etc.) and bridge through [Constant.{to_stable, of_stable}] (or
    the various other named-after-the-parent bridge functions:
    {!to_minimal} / {!to_in_circuit} / {!to_t_} /
    {!to_deferred_values} / {!to_messages_for_next_step_proof_t}).

    Each [Stable.V1.t] is constrained [= Mina_wire_types…V1.t]
    field-for-field, so the wire format is anchored externally and
    cannot drift here without a corresponding Mina_wire_types
    update. *)

module Wrap = struct
  module Proof_state = struct
    module Deferred_values = struct
      module Plonk = struct
        module Minimal = struct
          [%%versioned
          module Stable = struct
            module V1 = struct
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
                ; feature_flags :
                    'bool Pickles_types.Plonk_types.Features.Stable.V1.t
                }
              [@@deriving sexp, compare, yojson, hlist, hash, equal]

              let to_latest = Core_kernel.Fn.id
            end
          end]
        end
      end

      module Minimal = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            (* 'fp is unused in Minimal but kept for type compatibility with
               In_circuit, to preserve the serialization format. *)
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
      end

      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]

        module V1 = struct
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

          let to_latest = Core_kernel.Fn.id
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
    end

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
            }
          [@@deriving sexp, compare, yojson, hash, equal]
        end
      end]
    end
  end

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
  end
end

module Step = struct
  module Proof_state = struct
    module Deferred_values = struct
      module Plonk = struct
        module Minimal = struct
          [%%versioned
          module Stable = struct
            module V1 = struct
              type ('challenge, 'scalar_challenge) t =
                { alpha : 'scalar_challenge
                ; beta : 'challenge
                ; gamma : 'challenge
                ; zeta : 'scalar_challenge
                }
              [@@deriving sexp, compare, yojson, hlist, hash, equal]
            end
          end]
        end
      end
    end
  end
end
