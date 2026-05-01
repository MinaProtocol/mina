(** Messages-for-next-* records.

    Both records carry data that one wrap or step proof publishes for
    the next layer; extracted from
    [Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof]
    and [Composition_types.Wrap.Messages_for_next_step_proof]. *)

open Pickles_types
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

let index_to_field_elements =
  Pickles_base.Side_loaded_verification_key.index_to_field_elements

module Wrap_proof = struct
  include Wire.Wrap.Proof_state.Messages_for_next_wrap_proof

  (** Wire-format polymorphic skeleton. Concrete records below name it
      explicitly via {!Poly} rather than [include]ing it. *)
  module Poly = Wire.Wrap.Proof_state.Messages_for_next_wrap_proof

  let to_field_elements (type g f)
      { challenge_polynomial_commitment; old_bulletproof_challenges }
      ~g1:(g1_to_field_elements : g -> f list) =
    Array.concat
      [ Vector.to_array old_bulletproof_challenges
        |> Array.concat_map ~f:Vector.to_array
      ; Array.of_list (g1_to_field_elements challenge_polynomial_commitment)
      ]

  let wrap_typ g1 chal ~length =
    Wrap_impl.Typ.of_hlistable
      [ g1; Vector.wrap_typ chal length ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  (** Wire-form (out-of-circuit) instantiation: the challenge polynomial
      commitment is pinned to a [Tick.Curve.Affine.t] curve point;
      ['bulletproof_challenges] (a vector-of-vectors) stays parametric
      because the outer length varies per [Max_proofs_verified] and the
      inner is the constant [Tock.Rounds.n]. *)
  module Constant = struct
    type 'bulletproof_challenges t =
      { challenge_polynomial_commitment : Backend.Tick.Curve.Affine.t
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    let to_stable
        ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
          'bp t ) : (Backend.Tick.Curve.Affine.t, 'bp) Poly.t =
      { challenge_polynomial_commitment; old_bulletproof_challenges }

    let of_stable
        ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
          (Backend.Tick.Curve.Affine.t, 'bp) Poly.t ) : 'bp t =
      { challenge_polynomial_commitment; old_bulletproof_challenges }
  end

  let _ = fun (c : _ Constant.t) ->
    Constant.of_stable (Constant.to_stable c)

  (** Step-circuit (Tick) instantiation. The commitment is witnessed
      as a pair of Step field elements (affine coordinates). *)
  module Step = struct
    type 'bulletproof_challenges t =
      { challenge_polynomial_commitment :
          Step_impl.Field.t * Step_impl.Field.t
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    let to_stable
        ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
          'bp t ) : (Step_impl.Field.t * Step_impl.Field.t, 'bp) Poly.t =
      { challenge_polynomial_commitment; old_bulletproof_challenges }

    let of_stable
        ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
          (Step_impl.Field.t * Step_impl.Field.t, 'bp) Poly.t ) : 'bp t =
      { challenge_polynomial_commitment; old_bulletproof_challenges }
  end

  let _ = fun (s : _ Step.t) -> Step.of_stable (Step.to_stable s)

  (** Wrap-circuit (Tock) instantiation. *)
  module Wrap = struct
    type 'bulletproof_challenges t =
      { challenge_polynomial_commitment :
          Wrap_impl.Field.t * Wrap_impl.Field.t
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    let to_stable
        ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
          'bp t ) : (Wrap_impl.Field.t * Wrap_impl.Field.t, 'bp) Poly.t =
      { challenge_polynomial_commitment; old_bulletproof_challenges }

    let of_stable
        ({ challenge_polynomial_commitment; old_bulletproof_challenges } :
          (Wrap_impl.Field.t * Wrap_impl.Field.t, 'bp) Poly.t ) : 'bp t =
      { challenge_polynomial_commitment; old_bulletproof_challenges }
  end

  let _ = fun (w : _ Wrap.t) -> Wrap.of_stable (Wrap.to_stable w)
end

module Step_proof = struct
  type ('g, 's, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
    { app_state : 's
          (** The actual application-level state (e.g., for Mina, this is the protocol state which contains the
  merkle root of the ledger, state related to consensus, etc.) *)
    ; dlog_plonk_index : 'g Plonk_verification_key_evals.t
          (** The verification key corresponding to the wrap-circuit for this recursive proof system.
        It gets threaded through all the circuits so that the step circuits can verify proofs against
        it.
    *)
    ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
    ; old_bulletproof_challenges : 'bulletproof_challenges
    }
  [@@deriving sexp]

  let to_field_elements (type g f)
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      } ~app_state:app_state_to_field_elements ~comm ~(g : g -> f list) =
    Array.concat
      [ index_to_field_elements ~g:comm dlog_plonk_index
      ; app_state_to_field_elements app_state
      ; Vector.map2 challenge_polynomial_commitments
          old_bulletproof_challenges ~f:(fun comm chals ->
            Array.append (Array.of_list (g comm)) (Vector.to_array chals) )
        |> Vector.to_list |> Array.concat
      ]

  let to_field_elements_without_index (type g f)
      { app_state
      ; dlog_plonk_index = _
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      } ~app_state:app_state_to_field_elements ~(g : g -> f list) =
    Array.concat
      [ app_state_to_field_elements app_state
      ; Vector.map2 challenge_polynomial_commitments
          old_bulletproof_challenges ~f:(fun comm chals ->
            Array.append (Array.of_list (g comm)) (Vector.to_array chals) )
        |> Vector.to_list |> Array.concat
      ]

  (* Alias for [t]; must be defined BEFORE the [open Snarky_backendless
     .H_list] below, because that open brings [H_list.t] (2-arg) into
     scope and shadows the parent [t]. *)
  type ('a, 'b, 'c, 'd) messages_for_next_step_proof_t = ('a, 'b, 'c, 'd) t

  open Snarky_backendless.H_list

  let[@warning "-45"] to_hlist
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      } =
    [ app_state
    ; dlog_plonk_index
    ; challenge_polynomial_commitments
    ; old_bulletproof_challenges
    ]

  let[@warning "-45"] of_hlist
      ([ app_state
       ; dlog_plonk_index
       ; challenge_polynomial_commitments
       ; old_bulletproof_challenges
       ] :
        (unit, _) t ) =
    { app_state
    ; dlog_plonk_index
    ; challenge_polynomial_commitments
    ; old_bulletproof_challenges
    }

  (** Wire-form (out-of-circuit) instantiation: the commitment slot ['g]
      is pinned to [Backend.Tock.Curve.Affine.t], while ['s] (app
      state), ['challenge_polynomial_commitments], and
      ['bulletproof_challenges] remain parametric. *)
  module Constant = struct
    type ('s, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
      { app_state : 's
      ; dlog_plonk_index :
          Backend.Tock.Curve.Affine.t Plonk_verification_key_evals.t
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    let to_messages_for_next_step_proof_t
        ({ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } :
          ('s, 'cpc, 'bp) t ) :
        ( Backend.Tock.Curve.Affine.t
        , 's
        , 'cpc
        , 'bp )
        messages_for_next_step_proof_t =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }

    let of_messages_for_next_step_proof_t
        ({ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } :
          ( Backend.Tock.Curve.Affine.t
          , 's
          , 'cpc
          , 'bp )
          messages_for_next_step_proof_t ) : ('s, 'cpc, 'bp) t =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }
  end

  let _ = fun (c : (_, _, _) Constant.t) ->
    Constant.of_messages_for_next_step_proof_t
      (Constant.to_messages_for_next_step_proof_t c)

  (** Step-circuit (Tick) instantiation. *)
  module Step = struct
    type ('s, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
      { app_state : 's
      ; dlog_plonk_index :
          (Step_impl.Field.t * Step_impl.Field.t)
          Plonk_verification_key_evals.t
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    let to_messages_for_next_step_proof_t
        ({ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } :
          ('s, 'cpc, 'bp) t ) :
        ( Step_impl.Field.t * Step_impl.Field.t
        , 's
        , 'cpc
        , 'bp )
        messages_for_next_step_proof_t =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }

    let of_messages_for_next_step_proof_t
        ({ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } :
          ( Step_impl.Field.t * Step_impl.Field.t
          , 's
          , 'cpc
          , 'bp )
          messages_for_next_step_proof_t ) : ('s, 'cpc, 'bp) t =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }
  end

  let _ = fun (s : (_, _, _) Step.t) ->
    Step.of_messages_for_next_step_proof_t
      (Step.to_messages_for_next_step_proof_t s)

  (** Wrap-circuit (Tock) instantiation. *)
  module Wrap = struct
    type ('s, 'challenge_polynomial_commitments, 'bulletproof_challenges) t =
      { app_state : 's
      ; dlog_plonk_index :
          (Wrap_impl.Field.t * Wrap_impl.Field.t)
          Plonk_verification_key_evals.t
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    let to_messages_for_next_step_proof_t
        ({ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } :
          ('s, 'cpc, 'bp) t ) :
        ( Wrap_impl.Field.t * Wrap_impl.Field.t
        , 's
        , 'cpc
        , 'bp )
        messages_for_next_step_proof_t =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }

    let of_messages_for_next_step_proof_t
        ({ app_state
         ; dlog_plonk_index
         ; challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } :
          ( Wrap_impl.Field.t * Wrap_impl.Field.t
          , 's
          , 'cpc
          , 'bp )
          messages_for_next_step_proof_t ) : ('s, 'cpc, 'bp) t =
      { app_state
      ; dlog_plonk_index
      ; challenge_polynomial_commitments
      ; old_bulletproof_challenges
      }
  end

  let _ = fun (w : (_, _, _) Wrap.t) ->
    Wrap.of_messages_for_next_step_proof_t
      (Wrap.to_messages_for_next_step_proof_t w)
end
