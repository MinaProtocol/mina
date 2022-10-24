open Core_kernel
open Import
open Pickles_types
open Types
open Common
open Backend

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
    { Types.Step.Proof_state.Messages_for_next_step_proof.app_state
    ; challenge_polynomial_commitments
    ; dlog_plonk_index
    ; old_bulletproof_challenges =
        Vector.map ~f:Ipa.Step.compute_challenges old_bulletproof_challenges
    }
end

module Wrap = struct
  module Challenges_vector = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          Limb_vector.Constant.Hex64.Stable.V1.t Vector.Vector_2.Stable.V1.t
          Scalar_challenge.Stable.V2.t
          Bulletproof_challenge.Stable.V1.t
          Wrap_bp_vec.Stable.V1.t
        [@@deriving sexp, compare, yojson, hash, equal]

        let to_latest = Fn.id
      end
    end]

    type t =
      Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
      Wrap_bp_vec.t
    [@@deriving sexp, compare, yojson, hash, equal]

    let () =
      let _f : unit -> (t, Stable.Latest.t) Type_equal.t =
       fun () -> Type_equal.T
      in
      ()

    module Prepared = struct
      type t = (Wrap.Field.t, Wrap.Rounds.n) Vector.t
    end
  end

  type 'max_local_max_proofs_verified t =
    ( Wrap.Inner_curve.Affine.t
    , (Challenges_vector.t, 'max_local_max_proofs_verified) Vector.t )
    Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t

  module Prepared = struct
    type 'max_local_max_proofs_verified t =
      ( Wrap.Inner_curve.Affine.t
      , (Challenges_vector.Prepared.t, 'max_local_max_proofs_verified) Vector.t
      )
      Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t
  end

  let prepare
      ({ challenge_polynomial_commitment; old_bulletproof_challenges } : _ t) =
    { Types.Wrap.Proof_state.Messages_for_next_wrap_proof
      .challenge_polynomial_commitment
    ; old_bulletproof_challenges =
        Vector.map ~f:Ipa.Wrap.compute_challenges old_bulletproof_challenges
    }
end
