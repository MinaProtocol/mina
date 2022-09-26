open Core_kernel
open Pickles_types
open Import
open Common
open Backend

let hash_fold_array = Pickles_types.Plonk_types.hash_fold_array

module Base = struct
  module Messages_for_next_proof_over_same_field =
    Reduced_messages_for_next_proof_over_same_field

  module Step = struct
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
          Types.Step.Statement.t
      ; index : int
      ; prev_evals : 'prev_evals
      ; proof : Tick.Proof.t
      }
  end

  module Double = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'a t = 'a * 'a [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]
  end

  module Wrap = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
              ( 'messages_for_next_wrap_proof
              , 'messages_for_next_step_proof )
              Mina_wire_types.Pickles.Concrete_.Proof.Base.Wrap.V2.t =
          { statement :
              ( Limb_vector.Constant.Hex64.Stable.V1.t
                Vector.Vector_2.Stable.V1.t
              , Limb_vector.Constant.Hex64.Stable.V1.t
                Vector.Vector_2.Stable.V1.t
                Scalar_challenge.Stable.V2.t
              , Tick.Field.Stable.V1.t Shifted_value.Type1.Stable.V1.t
              , 'messages_for_next_wrap_proof
              , Digest.Constant.Stable.V1.t
              , 'messages_for_next_step_proof
              , Limb_vector.Constant.Hex64.Stable.V1.t
                Vector.Vector_2.Stable.V1.t
                Scalar_challenge.Stable.V2.t
                Bulletproof_challenge.Stable.V1.t
                Step_bp_vec.Stable.V1.t
              , Branch_data.Stable.V1.t )
              Types.Wrap.Statement.Minimal.Stable.V1.t
          ; prev_evals :
              ( Tick.Field.Stable.V1.t
              , Tick.Field.Stable.V1.t array )
              Plonk_types.All_evals.Stable.V1.t
          ; proof : Tock.Proof.Stable.V2.t
          }
        [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]

    type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
          ( 'messages_for_next_wrap_proof
          , 'messages_for_next_step_proof )
          Stable.Latest.t =
      { statement :
          ( Challenge.Constant.t
          , Challenge.Constant.t Scalar_challenge.t
          , Tick.Field.t Shifted_value.Type1.t
          , 'messages_for_next_wrap_proof
          , Digest.Constant.t
          , 'messages_for_next_step_proof
          , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
            Step_bp_vec.t
          , Branch_data.t )
          Types.Wrap.Statement.Minimal.t
      ; prev_evals : (Tick.Field.t, Tick.Field.t array) Plonk_types.All_evals.t
      ; proof : Tock.Proof.t
      }
    [@@deriving compare, sexp, yojson, hash, equal]
  end
end

type ('s, 'mlmb, 'c) with_data =
      ('s, 'mlmb, 'c) Mina_wire_types.Pickles.Concrete_.Proof.with_data =
  | T :
      ( 'mlmb Base.Messages_for_next_proof_over_same_field.Wrap.t
      , ( 's
        , (Tock.Curve.Affine.t, 'most_recent_width) Vector.t
        , ( Challenge.Constant.t Scalar_challenge.Stable.Latest.t
            Bulletproof_challenge.t
            Step_bp_vec.t
          , 'most_recent_width )
          Vector.t )
        Base.Messages_for_next_proof_over_same_field.Step.t )
      Base.Wrap.t
      -> ('s, 'mlmb, _) with_data

module With_data = struct
  type ('s, 'mlmb, 'w) t = ('s, 'mlmb, 'w) with_data
end

type ('max_width, 'mlmb) t = (unit, 'mlmb, 'max_width) With_data.t

let dummy (type w h r) (_w : w Nat.t) (h : h Nat.t)
    (most_recent_width : r Nat.t) ~domain_log2 : (w, h) t =
  let open Ro in
  let g0 = Tock.Curve.(to_affine_exn one) in
  let g len = Array.create ~len g0 in
  let tick_arr len = Array.init len ~f:(fun _ -> tick ()) in
  let lengths = Commitment_lengths.commitment_lengths in
  T
    { statement =
        { proof_state =
            { deferred_values =
                { xi = scalar_chal ()
                ; combined_inner_product = Shifted_value (tick ())
                ; b = Shifted_value (tick ())
                ; branch_data =
                    { proofs_verified =
                        ( match most_recent_width with
                        | Z ->
                            N0
                        | S Z ->
                            N1
                        | S (S Z) ->
                            N2
                        | _ ->
                            assert false )
                    ; domain_log2 =
                        Branch_data.Domain_log2.of_int_exn domain_log2
                    }
                ; bulletproof_challenges = Dummy.Ipa.Step.challenges
                ; plonk =
                    { alpha = scalar_chal ()
                    ; beta = chal ()
                    ; gamma = chal ()
                    ; zeta = scalar_chal ()
                    ; joint_combiner = None
                    }
                }
            ; sponge_digest_before_evaluations =
                Digest.Constant.of_tock_field Tock.Field.zero
            ; messages_for_next_wrap_proof =
                { challenge_polynomial_commitment = Lazy.force Dummy.Ipa.Step.sg
                ; old_bulletproof_challenges =
                    Vector.init h ~f:(fun _ -> Dummy.Ipa.Wrap.challenges)
                }
            }
        ; messages_for_next_step_proof =
            { app_state = ()
            ; old_bulletproof_challenges =
                (* Not sure if this should be w or h honestly ...*)
                Vector.init most_recent_width ~f:(fun _ ->
                    Dummy.Ipa.Step.challenges )
                (* TODO: Should this be wrap? *)
            ; challenge_polynomial_commitments =
                Vector.init most_recent_width ~f:(fun _ ->
                    Lazy.force Dummy.Ipa.Wrap.sg )
            }
        }
    ; proof =
        { messages =
            { w_comm = Vector.map lengths.w ~f:g
            ; z_comm = g lengths.z
            ; t_comm = g lengths.t
            ; lookup = None
            }
        ; openings =
            { proof =
                { lr =
                    Array.init (Nat.to_int Tock.Rounds.n) ~f:(fun _ -> (g0, g0))
                ; z_1 = Ro.tock ()
                ; z_2 = Ro.tock ()
                ; delta = g0
                ; challenge_polynomial_commitment = g0
                }
            ; evals = Dummy.evals.evals.evals
            ; ft_eval1 = Dummy.evals.ft_eval1
            }
        }
    ; prev_evals =
        (let e =
           Plonk_types.Evals.map Evaluation_lengths.constants ~f:(fun n ->
               (tick_arr n, tick_arr n) )
         in
         let ex =
           { Plonk_types.All_evals.With_public_input.public_input =
               (tick (), tick ())
           ; evals = e
           }
         in
         { ft_eval1 = tick (); evals = ex } )
    }

module Make (W : Nat.Intf) (MLMB : Nat.Intf) = struct
  module Max_proofs_verified_at_most = At_most.With_length (W)
  module MLMB_vec = Nvector (MLMB)

  module Repr = struct
    type t =
      ( ( Tock.Inner_curve.Affine.t
        , Reduced_messages_for_next_proof_over_same_field.Wrap.Challenges_vector
          .t
          MLMB_vec.t )
        Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t
      , ( unit
        , Tock.Curve.Affine.t Max_proofs_verified_at_most.t
        , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
          Step_bp_vec.t
          Max_proofs_verified_at_most.t )
        Base.Messages_for_next_proof_over_same_field.Step.t )
      Base.Wrap.t
    [@@deriving compare, sexp, yojson, hash, equal]
  end

  type nonrec t = (W.n, MLMB.n) t

  let to_repr (T t) : Repr.t =
    let lte =
      Nat.lte_exn
        (Vector.length
           t.statement.messages_for_next_step_proof
             .challenge_polynomial_commitments )
        W.n
    in
    { t with
      statement =
        { t.statement with
          messages_for_next_step_proof =
            { t.statement.messages_for_next_step_proof with
              challenge_polynomial_commitments =
                At_most.of_vector
                  t.statement.messages_for_next_step_proof
                    .challenge_polynomial_commitments lte
            ; old_bulletproof_challenges =
                At_most.of_vector
                  t.statement.messages_for_next_step_proof
                    .old_bulletproof_challenges lte
            }
        }
    }

  let of_repr (r : Repr.t) : t =
    let (Vector.T challenge_polynomial_commitments) =
      At_most.to_vector
        r.statement.messages_for_next_step_proof
          .challenge_polynomial_commitments
    in
    let (Vector.T old_bulletproof_challenges) =
      At_most.to_vector
        r.statement.messages_for_next_step_proof.old_bulletproof_challenges
    in
    let T =
      Nat.eq_exn
        (Vector.length challenge_polynomial_commitments)
        (Vector.length old_bulletproof_challenges)
    in
    T
      { r with
        statement =
          { r.statement with
            messages_for_next_step_proof =
              { r.statement.messages_for_next_step_proof with
                challenge_polynomial_commitments
              ; old_bulletproof_challenges
              }
          }
      }

  let compare t1 t2 = Repr.compare (to_repr t1) (to_repr t2)

  let equal t1 t2 = Repr.equal (to_repr t1) (to_repr t2)

  let hash_fold_t s t = Repr.hash_fold_t s (to_repr t)

  let hash t = Repr.hash (to_repr t)

  include
    Sexpable.Of_sexpable
      (Repr)
      (struct
        type nonrec t = t

        let to_sexpable = to_repr

        let of_sexpable = of_repr
      end)

  let to_base64 t =
    (* assume call to Nat.lte_exn does not raise with a valid instance of t *)
    let sexp = sexp_of_t t in
    (* raises only on invalid optional arguments *)
    Base64.encode_exn (Sexp.to_string sexp)

  let of_base64 b64 =
    match Base64.decode b64 with
    | Ok t -> (
        try Ok (t_of_sexp (Sexp.of_string t))
        with exn -> Error (Exn.to_string exn) )
    | Error (`Msg s) ->
        Error s

  let to_yojson_full x = Repr.to_yojson (to_repr x)

  let to_yojson x = `String (to_base64 x)

  let of_yojson = function
    | `String x ->
        of_base64 x
    | _ ->
        Error "Invalid json for proof. Expecting base64 encoded string"
end

module Proofs_verified_2 = struct
  module T = Make (Nat.N2) (Nat.N2)

  module Repr = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          ( ( Tock.Inner_curve.Affine.Stable.V1.t
            , Reduced_messages_for_next_proof_over_same_field.Wrap
              .Challenges_vector
              .Stable
              .V2
              .t
              Vector.Vector_2.Stable.V1.t )
            Types.Wrap.Proof_state.Messages_for_next_wrap_proof.Stable.V1.t
          , ( unit
            , Tock.Curve.Affine.t At_most.At_most_2.Stable.V1.t
            , Limb_vector.Constant.Hex64.Stable.V1.t Vector.Vector_2.Stable.V1.t
              Scalar_challenge.Stable.V2.t
              Bulletproof_challenge.Stable.V1.t
              Step_bp_vec.Stable.V1.t
              At_most.At_most_2.Stable.V1.t )
            Base.Messages_for_next_proof_over_same_field.Step.Stable.V1.t )
          Base.Wrap.Stable.V2.t
        [@@deriving compare, sexp, yojson, hash, equal]

        let to_latest = Fn.id
      end
    end]

    include T.Repr

    (* Force the typechecker to verify that these types are equal. *)
    let () =
      let _f : unit -> (t, Stable.Latest.t) Type_equal.t =
       fun () -> Type_equal.T
      in
      ()
  end

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = T.t

      let to_latest = Fn.id

      include (T : module type of T with type t := t with module Repr := T.Repr)

      include
        Binable.Of_binable
          (Repr.Stable.V2)
          (struct
            type nonrec t = t

            let to_binable = to_repr

            let of_binable = of_repr
          end)
    end
  end]

  include (T : module type of T with module Repr := T.Repr)
end

module Proofs_verified_max = struct
  module T =
    Make
      (Side_loaded_verification_key.Width.Max)
      (Side_loaded_verification_key.Width.Max)

  module Repr = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          ( ( Tock.Inner_curve.Affine.Stable.V1.t
            , Reduced_messages_for_next_proof_over_same_field.Wrap
              .Challenges_vector
              .Stable
              .V2
              .t
              Side_loaded_verification_key.Width.Max_vector.Stable.V1.t )
            Types.Wrap.Proof_state.Messages_for_next_wrap_proof.Stable.V1.t
          , ( unit
            , Tock.Curve.Affine.t
              Side_loaded_verification_key.Width.Max_at_most.Stable.V1.t
            , Limb_vector.Constant.Hex64.Stable.V1.t Vector.Vector_2.Stable.V1.t
              Scalar_challenge.Stable.V2.t
              Bulletproof_challenge.Stable.V1.t
              Step_bp_vec.Stable.V1.t
              Side_loaded_verification_key.Width.Max_at_most.Stable.V1.t )
            Base.Messages_for_next_proof_over_same_field.Step.Stable.V1.t )
          Base.Wrap.Stable.V2.t
        [@@deriving compare, sexp, yojson, hash, equal]

        let to_latest = Fn.id
      end
    end]

    include T.Repr

    (* Force the typechecker to verify that these types are equal. *)
    let () =
      let _f : unit -> (t, Stable.Latest.t) Type_equal.t =
       fun () -> Type_equal.T
      in
      ()
  end

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = T.t

      let to_latest = Fn.id

      include (T : module type of T with type t := t with module Repr := T.Repr)

      include
        Binable.Of_binable
          (Repr.Stable.V2)
          (struct
            type nonrec t = t

            let to_binable = to_repr

            let of_binable = of_repr
          end)
    end
  end]

  include (T : module type of T with module Repr := T.Repr)
end
