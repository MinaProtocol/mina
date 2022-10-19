(* The step-proof "reduced" me-only contains the data of the standard me-only
   but without the wrap verification key. The purpose of this type is for sending
   step me-onlys on the wire. There is no need to send the wrap-key since everyone
   knows it. *)
module Step = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('s, 'challenge_polynomial_commitments, 'bpcs) t =
            ( 's
            , 'challenge_polynomial_commitments
            , 'bpcs )
            Mina_wire_types
            .Pickles_reduced_messages_for_next_proof_over_same_field
            .Step
            .V1
            .t =
        { app_state : 's
        ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
        ; old_bulletproof_challenges : 'bpcs
        }
      [@@deriving sexp, yojson, sexp, compare, hash, equal]
    end
  end]

  let prepare ~dlog_plonk_index
      { app_state
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      } =
    { Import.Types.Step.Proof_state.Messages_for_next_step_proof.app_state
    ; challenge_polynomial_commitments
    ; dlog_plonk_index
    ; old_bulletproof_challenges =
        Pickles_types.Vector.map ~f:Common.Ipa.Step.compute_challenges
          old_bulletproof_challenges
    }
end

module Wrap = struct
  module Challenges_vector = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          Limb_vector.Constant.Hex64.Stable.V1.t
          Pickles_types.Vector.Vector_2.Stable.V1.t
          Import.Scalar_challenge.Stable.V2.t
          Import.Bulletproof_challenge.Stable.V1.t
          Import.Types.Wrap_bp_vec.Stable.V1.t
        [@@deriving sexp, compare, yojson, hash, equal]

        let to_latest = Core_kernel.Fn.id
      end
    end]

    type t =
      Import.Challenge.Constant.t Import.Scalar_challenge.t
      Import.Bulletproof_challenge.t
      Import.Types.Wrap_bp_vec.t
    [@@deriving sexp, compare, yojson, hash, equal]

    let () =
      let _f : unit -> (t, Stable.Latest.t) Core_kernel.Type_equal.t =
       fun () -> Core_kernel.Type_equal.T
      in
      ()

    module Prepared = struct
      type t =
        (Backend.Tock.Field.t, Backend.Tock.Rounds.n) Pickles_types.Vector.t
    end
  end

  type 'max_local_max_proofs_verified t =
    ( Backend.Tock.Inner_curve.Affine.t
    , ( Challenges_vector.t
      , 'max_local_max_proofs_verified )
      Pickles_types.Vector.t )
    Import.Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t

  module Prepared = struct
    type 'max_local_max_proofs_verified t =
      ( Backend.Tock.Inner_curve.Affine.t
      , ( Challenges_vector.Prepared.t
        , 'max_local_max_proofs_verified )
        Pickles_types.Vector.t )
      Import.Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t
  end

  let prepare
      ({ challenge_polynomial_commitment; old_bulletproof_challenges } : _ t) =
    { Import.Types.Wrap.Proof_state.Messages_for_next_wrap_proof
      .challenge_polynomial_commitment
    ; old_bulletproof_challenges =
        Pickles_types.Vector.map ~f:Common.Ipa.Wrap.compute_challenges
          old_bulletproof_challenges
    }
end
