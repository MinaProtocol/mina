open Core_kernel
open Pickles_types
open Import
open Common
open Backend

let hash_fold_array = Pickles_types.Plonk_types.hash_fold_array

module Base = struct
  module Me_only = Reduced_me_only

  module Step = struct
    type ( 's
         , 'unfinalized_proofs
         , 'sgs
         , 'bp_chals
         , 'dlog_me_onlys
         , 'prev_evals )
         t =
      { statement :
          ( 'unfinalized_proofs
          , ('s, 'sgs, 'bp_chals) Me_only.Step.t
          , 'dlog_me_onlys )
          Types.Step.Statement.t
      ; index : Types.Index.t
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
        type ('dlog_me_only, 'step_me_only) t =
          { statement :
              ( Limb_vector.Constant.Hex64.Stable.V1.t
                Vector.Vector_2.Stable.V1.t
              , Limb_vector.Constant.Hex64.Stable.V1.t
                Vector.Vector_2.Stable.V1.t
                Scalar_challenge.Stable.V2.t
              , Tick.Field.Stable.V1.t Shifted_value.Type1.Stable.V1.t
              , Tock.Field.Stable.V1.t
              , 'dlog_me_only
              , Digest.Constant.Stable.V1.t
              , 'step_me_only
              , Limb_vector.Constant.Hex64.Stable.V1.t
                Vector.Vector_2.Stable.V1.t
                Scalar_challenge.Stable.V2.t
                Bulletproof_challenge.Stable.V1.t
                Step_bp_vec.Stable.V1.t
              , Index.Stable.V1.t )
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

    type ('dlog_me_only, 'step_me_only) t =
          ('dlog_me_only, 'step_me_only) Stable.Latest.t =
      { statement :
          ( Challenge.Constant.t
          , Challenge.Constant.t Scalar_challenge.t
          , Tick.Field.t Shifted_value.Type1.t
          , Tock.Field.t
          , 'dlog_me_only
          , Digest.Constant.t
          , 'step_me_only
          , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
            Step_bp_vec.t
          , Index.t )
          Types.Wrap.Statement.Minimal.t
      ; prev_evals : (Tick.Field.t, Tick.Field.t array) Plonk_types.All_evals.t
      ; proof : Tock.Proof.t
      }
    [@@deriving compare, sexp, yojson, hash, equal]
  end
end

type ('s, 'mlmb, _) with_data =
  | T :
      ( 'mlmb Base.Me_only.Wrap.t
      , ( 's
        , (Tock.Curve.Affine.t, 'most_recent_width) Vector.t
        , ( Challenge.Constant.t Scalar_challenge.Stable.Latest.t
            Bulletproof_challenge.t
            Step_bp_vec.t
          , 'most_recent_width )
          Vector.t )
        Base.Me_only.Step.t )
      Base.Wrap.t
      -> ('s, 'mlmb, _) with_data

module With_data = struct
  type ('s, 'mlmb, 'w) t = ('s, 'mlmb, 'w) with_data
end

type ('max_width, 'mlmb) t = (unit, 'mlmb, 'max_width) With_data.t

let dummy (type w h r) (_w : w Nat.t) (h : h Nat.t)
    (most_recent_width : r Nat.t) : (w, h) t =
  let open Ro in
  let g0 = Tock.Curve.(to_affine_exn one) in
  let g len = Array.create ~len g0 in
  let tick_arr len = Array.init len ~f:(fun _ -> tick ()) in
  let lengths = Commitment_lengths.create ~of_int:Fn.id in
  T
    { statement =
        { proof_state =
            { deferred_values =
                { xi = scalar_chal ()
                ; combined_inner_product = Shifted_value (tick ())
                ; b = Shifted_value (tick ())
                ; which_branch = Option.value_exn (Index.of_int 0)
                ; bulletproof_challenges = Dummy.Ipa.Step.challenges
                ; plonk =
                    { alpha = scalar_chal ()
                    ; beta = chal ()
                    ; gamma = chal ()
                    ; zeta = scalar_chal ()
                    }
                }
            ; sponge_digest_before_evaluations =
                Digest.Constant.of_tock_field Tock.Field.zero
            ; me_only =
                { sg = Lazy.force Dummy.Ipa.Step.sg
                ; old_bulletproof_challenges =
                    Vector.init h ~f:(fun _ -> Dummy.Ipa.Wrap.challenges)
                }
            }
        ; pass_through =
            { app_state = ()
            ; old_bulletproof_challenges =
                (* Not sure if this should be w or h honestly ...*)
                Vector.init most_recent_width ~f:(fun _ ->
                    Dummy.Ipa.Step.challenges)
                (* TODO: Should this be wrap? *)
            ; sg =
                Vector.init most_recent_width ~f:(fun _ ->
                    Lazy.force Dummy.Ipa.Wrap.sg)
            }
        }
    ; proof =
        { messages =
            { w_comm = Vector.map lengths.w ~f:g
            ; z_comm = g lengths.z
            ; t_comm = g lengths.t
            }
        ; openings =
            { proof =
                { lr =
                    Array.init (Nat.to_int Tock.Rounds.n) ~f:(fun _ -> (g0, g0))
                ; z_1 = Ro.tock ()
                ; z_2 = Ro.tock ()
                ; delta = g0
                ; sg = g0
                }
            ; evals =
                Tuple_lib.Double.map Dummy.evals.evals ~f:(fun e -> e.evals)
            ; ft_eval1 = Dummy.evals.ft_eval1
            }
        }
    ; prev_evals =
        (let e () =
           Plonk_types.Evals.map
             (Evaluation_lengths.create ~of_int:Fn.id)
             ~f:tick_arr
         in
         let ex () =
           { Plonk_types.All_evals.With_public_input.public_input = tick ()
           ; evals = e ()
           }
         in
         { ft_eval1 = tick (); evals = (ex (), ex ()) })
    }

module Make (W : Nat.Intf) (MLMB : Nat.Intf) = struct
  module Max_branching_at_most = At_most.With_length (W)
  module MLMB_vec = Nvector (MLMB)

  module Repr = struct
    type t =
      ( ( Tock.Inner_curve.Affine.t
        , Reduced_me_only.Wrap.Challenges_vector.t MLMB_vec.t )
        Types.Wrap.Proof_state.Me_only.t
      , ( unit
        , Tock.Curve.Affine.t Max_branching_at_most.t
        , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
          Step_bp_vec.t
          Max_branching_at_most.t )
        Base.Me_only.Step.t )
      Base.Wrap.t
    [@@deriving compare, sexp, yojson, hash, equal]
  end

  type nonrec t = (W.n, MLMB.n) t

  let to_repr (T t) : Repr.t =
    let lte = Nat.lte_exn (Vector.length t.statement.pass_through.sg) W.n in
    { t with
      statement =
        { t.statement with
          pass_through =
            { t.statement.pass_through with
              sg = At_most.of_vector t.statement.pass_through.sg lte
            ; old_bulletproof_challenges =
                At_most.of_vector
                  t.statement.pass_through.old_bulletproof_challenges lte
            }
        }
    }

  let of_repr (r : Repr.t) : t =
    let (Vector.T sg) = At_most.to_vector r.statement.pass_through.sg in
    let (Vector.T old_bulletproof_challenges) =
      At_most.to_vector r.statement.pass_through.old_bulletproof_challenges
    in
    let T =
      Nat.eq_exn (Vector.length sg) (Vector.length old_bulletproof_challenges)
    in
    T
      { r with
        statement =
          { r.statement with
            pass_through =
              { r.statement.pass_through with sg; old_bulletproof_challenges }
          }
      }

  let compare t1 t2 = Repr.compare (to_repr t1) (to_repr t2)

  let equal t1 t2 = Repr.equal (to_repr t1) (to_repr t2)

  let hash_fold_t s t = Repr.hash_fold_t s (to_repr t)

  let hash t = Repr.hash (to_repr t)

  include Sexpable.Of_sexpable
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

module Branching_2 = struct
  module T = Make (Nat.N2) (Nat.N2)

  module Repr = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          ( ( Tock.Inner_curve.Affine.Stable.V1.t
            , Reduced_me_only.Wrap.Challenges_vector.Stable.V2.t
              Vector.Vector_2.Stable.V1.t )
            Types.Wrap.Proof_state.Me_only.Stable.V1.t
          , ( unit
            , Tock.Curve.Affine.t At_most.At_most_2.Stable.V1.t
            , Limb_vector.Constant.Hex64.Stable.V1.t Vector.Vector_2.Stable.V1.t
              Scalar_challenge.Stable.V2.t
              Bulletproof_challenge.Stable.V1.t
              Step_bp_vec.Stable.V1.t
              At_most.At_most_2.Stable.V1.t )
            Base.Me_only.Step.Stable.V1.t )
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

      include Binable.Of_binable
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

module Branching_max = struct
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
            , Reduced_me_only.Wrap.Challenges_vector.Stable.V2.t
              Side_loaded_verification_key.Width.Max_vector.Stable.V1.t )
            Types.Wrap.Proof_state.Me_only.Stable.V1.t
          , ( unit
            , Tock.Curve.Affine.t
              Side_loaded_verification_key.Width.Max_at_most.Stable.V1.t
            , Limb_vector.Constant.Hex64.Stable.V1.t Vector.Vector_2.Stable.V1.t
              Scalar_challenge.Stable.V2.t
              Bulletproof_challenge.Stable.V1.t
              Step_bp_vec.Stable.V1.t
              Side_loaded_verification_key.Width.Max_at_most.Stable.V1.t )
            Base.Me_only.Step.Stable.V1.t )
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

      include Binable.Of_binable
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
