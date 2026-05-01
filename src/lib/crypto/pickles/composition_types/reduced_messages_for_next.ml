(** Concrete (non-versioned) records mirroring
    [Pickles.Reduced_messages_for_next_proof_over_same_field].

    The versioned/[bin_io] type lives in
    [src/lib/crypto/pickles/reduced_messages_for_next_proof_over_same_field.ml].
    The records here are constrained equal to the corresponding
    [Mina_wire_types] skeleton so that values flow freely between the
    two modules without conversion. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Wrap_bp_vec = Backend.Tock.Rounds_vector

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
    Messages_for_next.Wrap_proof.Poly.t
end
