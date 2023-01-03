module Base : sig
  module Messages_for_next_proof_over_same_field =
    Reduced_messages_for_next_proof_over_same_field

  module Step : sig
    type ( 's
         , 'unfinalized_proofs
         , 'sgs
         , 'bp_chals
         , 'messages_for_next_wrap_proof
         , 'prev_evals )
         t =
      { statement :
          ( 'unfinalized_proofs
          , ('s, 'sgs, 'bp_chals) Messages_for_next_proof_over_same_field.Step.t
          , 'messages_for_next_wrap_proof )
          Import.Types.Step.Statement.t
      ; index : int
      ; prev_evals : 'prev_evals
      ; proof : Backend.Tick.Proof.t
      }
  end

  module Wrap : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
              ( 'messages_for_next_wrap_proof
              , 'messages_for_next_step_proof )
              Mina_wire_types.Pickles.Concrete_.Proof.Base.Wrap.V2.t =
          { statement :
              ( Limb_vector.Constant.Hex64.Stable.V1.t
                Pickles_types.Vector.Vector_2.Stable.V1.t
              , Limb_vector.Constant.Hex64.Stable.V1.t
                Pickles_types.Vector.Vector_2.Stable.V1.t
                Import.Scalar_challenge.Stable.V2.t
              , Backend.Tick.Field.Stable.V1.t
                Pickles_types.Shifted_value.Type1.Stable.V1.t
              , 'messages_for_next_wrap_proof
              , Import.Digest.Constant.Stable.V1.t
              , 'messages_for_next_step_proof
              , Limb_vector.Constant.Hex64.Stable.V1.t
                Pickles_types.Vector.Vector_2.Stable.V1.t
                Import.Scalar_challenge.Stable.V2.t
                Import.Bulletproof_challenge.Stable.V1.t
                Import.Step_bp_vec.Stable.V1.t
              , Import.Branch_data.Stable.V1.t )
              Import.Types.Wrap.Statement.Minimal.Stable.V1.t
          ; prev_evals :
              ( Backend.Tick.Field.Stable.V1.t
              , Backend.Tick.Field.Stable.V1.t array )
              Pickles_types.Plonk_types.All_evals.Stable.V1.t
          ; proof : Backend.Tock.Proof.Stable.V2.t
          }
        [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]

    type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
          ( 'messages_for_next_wrap_proof
          , 'messages_for_next_step_proof )
          Stable.Latest.t =
      { statement :
          ( Import.Challenge.Constant.t
          , Import.Challenge.Constant.t Import.Scalar_challenge.t
          , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
          , 'messages_for_next_wrap_proof
          , Import.Digest.Constant.t
          , 'messages_for_next_step_proof
          , Import.Challenge.Constant.t Import.Scalar_challenge.t
            Import.Bulletproof_challenge.t
            Import.Step_bp_vec.t
          , Import.Branch_data.t )
          Import.Types.Wrap.Statement.Minimal.t
      ; prev_evals :
          ( Backend.Tick.Field.t
          , Backend.Tick.Field.t array )
          Pickles_types.Plonk_types.All_evals.t
      ; proof : Backend.Tock.Proof.t
      }
    [@@deriving compare, sexp, yojson, hash, equal]
  end
end

type ('s, 'mlmb, 'c) with_data =
      ('s, 'mlmb, 'c) Mina_wire_types.Pickles.Concrete_.Proof.with_data =
  | T :
      ( 'mlmb Base.Messages_for_next_proof_over_same_field.Wrap.t
      , ( 's
        , ( Backend.Tock.Curve.Affine.t
          , 'most_recent_width )
          Pickles_types.Vector.t
        , ( Import.Challenge.Constant.t Import.Scalar_challenge.Stable.Latest.t
            Import.Bulletproof_challenge.t
            Import.Step_bp_vec.t
          , 'most_recent_width )
          Pickles_types.Vector.t )
        Base.Messages_for_next_proof_over_same_field.Step.t )
      Base.Wrap.t
      -> ('s, 'mlmb, _) with_data

type ('max_width, 'mlmb) t = (unit, 'mlmb, 'max_width) with_data

val dummy :
     'w Pickles_types.Nat.t
  -> 'h Pickles_types.Nat.t
  -> 'r Pickles_types.Nat.t
  -> domain_log2:int
  -> ('w, 'h) t

module Make (W : Pickles_types.Nat.Intf) (MLMB : Pickles_types.Nat.Intf) : sig
  module Max_proofs_verified_at_most :
      module type of Pickles_types.At_most.With_length (W)

  module MLMB_vec : module type of Import.Nvector (MLMB)

  module Repr : sig
    type t =
      ( ( Backend.Tock.Inner_curve.Affine.t
        , Reduced_messages_for_next_proof_over_same_field.Wrap.Challenges_vector
          .t
          MLMB_vec.t )
        Import.Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t
      , ( unit
        , Backend.Tock.Curve.Affine.t Max_proofs_verified_at_most.t
        , Import.Challenge.Constant.t Import.Scalar_challenge.t
          Import.Bulletproof_challenge.t
          Import.Step_bp_vec.t
          Max_proofs_verified_at_most.t )
        Base.Messages_for_next_proof_over_same_field.Step.t )
      Base.Wrap.t
    [@@deriving compare, sexp, yojson, hash, equal]
  end

  type nonrec t = (W.n, MLMB.n) t [@@deriving compare, sexp, hash, equal]

  val to_base64 : t -> string

  val of_base64 : string -> (t, string) result

  val to_yojson : t -> [> `String of string ]

  val to_yojson_full : t Pickles_types.Sigs.jsonable

  val of_yojson : [> `String of string ] -> (t, string) result
end

module Proofs_verified_2 : sig
  module T : module type of Make (Pickles_types.Nat.N2) (Pickles_types.Nat.N2)

  [%%versioned:
  module Stable : sig
    module V2 : sig
      include module type of T with module Repr := T.Repr

      include Pickles_types.Sigs.VERSIONED

      include Pickles_types.Sigs.Binable.S with type t := t
    end
  end]

  include module type of (T : module type of T with module Repr := T.Repr)
end

module Proofs_verified_max : sig
  module T :
      module type of
        Make
          (Side_loaded_verification_key.Width.Max)
          (Side_loaded_verification_key.Width.Max)

  [%%versioned:
  module Stable : sig
    module V2 : sig
      include module type of T with module Repr := T.Repr

      include Pickles_types.Sigs.VERSIONED

      include Pickles_types.Sigs.Binable.S with type t := t
    end
  end]

  include module type of (T : module type of T with module Repr := T.Repr)
end
