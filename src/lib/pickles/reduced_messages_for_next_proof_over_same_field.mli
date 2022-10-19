(* *)

module Step : sig
  module Stable : sig
    module V1 : sig
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
      [@@deriving sexp, yojson, sexp, compare, hash, equal, bin_shape, bin_io]

      include Pickles_types.Sigs.VERSIONED
    end
  end

  type ('s, 'challenge_polynomial_commitments, 'bpcs) t =
        ( 's
        , 'challenge_polynomial_commitments
        , 'bpcs )
        Mina_wire_types.Pickles_reduced_messages_for_next_proof_over_same_field
        .Step
        .V1
        .t =
    { app_state : 's
    ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
    ; old_bulletproof_challenges : 'bpcs
    }
  [@@deriving sexp, yojson, sexp, compare, hash, equal]

  val prepare :
       dlog_plonk_index:'a Pickles_types.Plonk_verification_key_evals.t
    -> ( 'b
       , 'c
       , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
             Import.Bulletproof_challenge.t
           , 'd )
           Pickles_types.Vector.t
         , 'e )
         Pickles_types.Vector.t )
       t
    -> ( 'a
       , 'b
       , 'c
       , ( (Backend.Tick.Field.t, 'd) Pickles_types.Vector.t
         , 'e )
         Pickles_types.Vector.t )
       Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
end

module Wrap : sig
  module Challenges_vector : sig
    module Stable : sig
      module V2 : sig
        type t =
          Limb_vector.Constant.Hex64.Stable.V1.t
          Pickles_types.Vector.Vector_2.Stable.V1.t
          Import.Scalar_challenge.Stable.V2.t
          Import.Bulletproof_challenge.Stable.V1.t
          Import.Types.Wrap_bp_vec.Stable.V1.t
        [@@deriving sexp, compare, yojson, hash, equal, bin_shape, bin_io]

        include Pickles_types.Sigs.VERSIONED
      end
    end

    type t =
      Import.Challenge.Constant.t Import.Scalar_challenge.t
      Import.Bulletproof_challenge.t
      Import.Types.Wrap_bp_vec.t
    [@@deriving sexp, compare, yojson, hash, equal]

    module Prepared : sig
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

  val prepare :
       'a t
    -> ( Backend.Tock.Inner_curve.Affine.t
       , ( ( Backend.Tock.Field.t
           , Kimchi_pasta__Basic.Rounds.Wrap.n )
           Pickles_types.Vector.t
         , 'a )
         Pickles_types.Vector.t )
       Import.Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t

  module Prepared : sig
    type 'max_local_max_proofs_verified t =
      ( Backend.Tock.Inner_curve.Affine.t
      , ( Challenges_vector.Prepared.t
        , 'max_local_max_proofs_verified )
        Pickles_types.Vector.t )
      Import.Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t
  end
end
