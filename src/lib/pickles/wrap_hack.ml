open Core_kernel
open Backend
open Pickles_types

(* The actual "accumulator" for the wrap proof contains a vector of elements,
   each of which is a vector of bulletproof challenges.

   The number of such vectors is equal to the maximum proofs-verified
   amongst all the step branches that that proof is wrapping.

   To simplify the implementation when the number of proofs-verified
   varies across proof systems (being either 0, 1, or 2) we secretly
   pad the accumulator so that it always has exactly 2 vectors, padding
   with dummy vectors.

   We also then pad with the corresponding dummy commitments when proving
   wrap statements, as in `pad_accumulator` which is used in wrap.ml.

   We add them to the **front**, not the back, of the vector of the actual
   "real" accumulator values so that we can precompute the sponge states
   resulting from absorbing the padding challenges
*)

module Padded_length = Nat.N2

(* Pad up to length 2 by preprending dummy values. *)
let pad_vector (type a) ~dummy (v : (a, _) Vector.t) =
  Vector.extend_front_exn v Padded_length.n dummy

(* Specialized padding function. *)
let pad_challenges (chalss : (_ Vector.t, _) Vector.t) =
  pad_vector ~dummy:(Lazy.force Dummy.Ipa.Wrap.challenges_computed) chalss

(* Specialized padding function. *)
let pad_accumulator (xs : (Tock.Proof.Challenge_polynomial.t, _) Vector.t) =
  pad_vector xs
    ~dummy:
      { Tock.Proof.Challenge_polynomial.commitment =
          Lazy.force Dummy.Ipa.Wrap.sg
      ; challenges =
          Vector.to_array (Lazy.force Dummy.Ipa.Wrap.challenges_computed)
      }
  |> Vector.to_list

(* Hash the me only, padding first. *)
let hash_messages_for_next_wrap_proof (type n) (_max_proofs_verified : n Nat.t)
    (t :
      ( Tick.Curve.Affine.t
      , (_, n) Vector.t )
      Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.t ) =
  let t =
    { t with
      old_bulletproof_challenges = pad_challenges t.old_bulletproof_challenges
    }
  in
  Tock_field_sponge.digest Tock_field_sponge.params
    (Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof
     .to_field_elements t ~g1:(fun ((x, y) : Tick.Curve.Affine.t) -> [ x; y ])
    )

(* Pad the messages_for_next_wrap_proof of a proof *)
let pad_proof (type mlmb) (T p : (mlmb, _) Proof.t) :
    Proof.Proofs_verified_max.t =
  T
    { p with
      statement =
        { p.statement with
          proof_state =
            { p.statement.proof_state with
              messages_for_next_wrap_proof =
                { p.statement.proof_state.messages_for_next_wrap_proof with
                  old_bulletproof_challenges =
                    pad_vector
                      p.statement.proof_state.messages_for_next_wrap_proof
                        .old_bulletproof_challenges
                      ~dummy:Dummy.Ipa.Wrap.challenges
                }
            }
        }
    }

module Checked = struct
  let pad_challenges (chalss : (_ Vector.t, _) Vector.t) =
    pad_vector
      ~dummy:
        (Vector.map ~f:Impls.Wrap.Field.constant
           (Lazy.force Dummy.Ipa.Wrap.challenges_computed) )
      chalss

  let pad_commitments (commitments : _ Vector.t) =
    pad_vector
      ~dummy:
        (Tuple_lib.Double.map ~f:Impls.Step.Field.constant
           (Lazy.force Dummy.Ipa.Wrap.sg) )
      commitments

  (* We precompute the sponge states that would result from absorbing
     0, 1, or 2 dummy challenge vectors. This is used to speed up hashing
     inside the circuit. *)
  let dummy_messages_for_next_wrap_proof_sponge_states =
    lazy
      (let module S = Tock_field_sponge.Field in
      let full_state s = (S.state s, s.sponge_state) in
      let sponge = S.create Tock_field_sponge.params in
      let s0 = full_state sponge in
      let chals = Lazy.force Dummy.Ipa.Wrap.challenges_computed in
      Vector.iter ~f:(S.absorb sponge) chals ;
      let s1 = full_state sponge in
      Vector.iter ~f:(S.absorb sponge) chals ;
      let s2 = full_state sponge in
      [| s0; s1; s2 |] )

  let hash_constant_messages_for_next_wrap_proof =
    hash_messages_for_next_wrap_proof

  (* TODO: No need to hash the entire bulletproof challenges. Could
     just hash the segment of the public input LDE corresponding to them
     that we compute when verifying the previous proof. That is a commitment
     to them. *)
  let hash_messages_for_next_wrap_proof (type n) (max_proofs_verified : n Nat.t)
      (t :
        ( Wrap_main_inputs.Inner_curve.t
        , ((Impls.Wrap.Field.t, Backend.Tock.Rounds.n) Vector.t, n) Vector.t )
        Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.t ) =
    let open Wrap_main_inputs in
    let sponge =
      (* The sponge states we would reach if we absorbed the padding challenges *)
      let s = Sponge.create sponge_params in
      let state, sponge_state =
        (Lazy.force dummy_messages_for_next_wrap_proof_sponge_states).(2
                                                                       - Nat
                                                                         .to_int
                                                                           max_proofs_verified)
      in
      { s with
        state = Array.map state ~f:Impls.Wrap.Field.constant
      ; sponge_state
      }
    in
    Array.iter ~f:(Sponge.absorb sponge)
      (Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof
       .to_field_elements ~g1:Inner_curve.to_field_elements t ) ;
    Sponge.squeeze_field sponge
end
