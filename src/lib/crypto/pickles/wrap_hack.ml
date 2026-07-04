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

(* Specialized padding function. Pads (at the front) up to [max (2, n)] dummy
   challenge vectors; the result is length-agnostic (a list). *)
let pad_challenges (chalss : (_ Vector.t, _) Vector.t) =
  let dummy = Lazy.force Dummy.Ipa.Wrap.challenges_computed in
  let chalss = Vector.to_list chalss in
  let num_padding =
    Int.max 0 (Nat.to_int Padded_length.n - List.length chalss)
  in
  List.init num_padding ~f:(fun _ -> dummy) @ chalss

(* Specialized padding function. Pads (at the front) up to [max (2, n)] dummy
   accumulator entries; the result is length-agnostic (a list). *)
let pad_accumulator (xs : (Tock.Proof.Challenge_polynomial.t, _) Vector.t) =
  let dummy =
    { Tock.Proof.Challenge_polynomial.commitment = Lazy.force Dummy.Ipa.Wrap.sg
    ; challenges =
        Vector.to_array (Lazy.force Dummy.Ipa.Wrap.challenges_computed)
    }
  in
  let xs = Vector.to_list xs in
  let num_padding = Int.max 0 (Nat.to_int Padded_length.n - List.length xs) in
  List.init num_padding ~f:(fun _ -> dummy) @ xs

(* Hash the me only, padding first. The accumulator is padded (at the front) up
   to [max (2, n)] vectors of dummy challenges. *)
let hash_messages_for_next_wrap_proof (type n)
    (t :
      ( Tick.Curve.Affine.t
      , (_, n) Vector.t )
      Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.t ) =
  let old = t.old_bulletproof_challenges in
  let (Nat.Max.T (padded_length, _, _)) =
    Nat.max Padded_length.n (Vector.length old)
  in
  let t =
    { t with
      old_bulletproof_challenges =
        Vector.extend_front_exn old padded_length
          (Lazy.force Dummy.Ipa.Wrap.challenges_computed)
    }
  in
  Tock_field_sponge.digest Tock_field_sponge.params
    (Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof
     .to_field_elements t ~g1:(fun ((x, y) : Tick.Curve.Affine.t) -> [ x; y ])
    )

(* Pad the messages_for_next_wrap_proof of a proof *)
let pad_proof (type mlmb) (T p : mlmb Proof.t) : Proof.Proofs_verified_max.t =
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
  (* Pad (at the front) up to [max (2, n)] dummy challenge vectors. The padded
     width is named [(Padded_length.n, n) Max_type.t] so it does not escape. *)
  let pad_challenges (type n)
      (chalss :
        ((Impls.Wrap.Field.t, Backend.Tock.Rounds.n) Vector.t, n) Vector.t ) :
      ( (Impls.Wrap.Field.t, Backend.Tock.Rounds.n) Vector.t
      , (Padded_length.n, n) Nat.Max_type.t )
      Vector.t =
    let dummy =
      Vector.map ~f:Impls.Wrap.Field.constant
        (Lazy.force Dummy.Ipa.Wrap.challenges_computed)
    in
    let module L = Core_kernel.Type_equal.Lift (struct
      type 'a t =
        ((Impls.Wrap.Field.t, Backend.Tock.Rounds.n) Vector.t, 'a) Vector.t
    end) in
    match Nat.compare Padded_length.n (Vector.length chalss) with
    | `Lte le ->
        Core_kernel.Type_equal.conv
          (Core_kernel.Type_equal.sym (L.lift (Nat.Max_type.le le)))
          (Vector.extend_front_exn chalss (Vector.length chalss) dummy)
    | `Gt gt ->
        Core_kernel.Type_equal.conv
          (Core_kernel.Type_equal.sym
             (L.lift
                (Nat.Max_type.ge
                   (Nat.gt_implies_gte Padded_length.n (Vector.length chalss) gt) ) ) )
          (Vector.extend_front_exn chalss Padded_length.n dummy)

  (* Pad (at the front) up to [max (2, n)] dummy commitments, to match the
     accumulator width of the proof being verified. The padded width is named
     [(Padded_length.n, n) Max_type.t] so it does not escape as an existential. *)
  let pad_commitments (type n) (commitments : (_, n) Vector.t) :
      (_, (Padded_length.n, n) Nat.Max_type.t) Vector.t =
    let dummy =
      Tuple_lib.Double.map ~f:Impls.Step.Field.constant
        (Lazy.force Dummy.Ipa.Wrap.sg)
    in
    let module L = Core_kernel.Type_equal.Lift (struct
      type 'a t = (Impls.Step.Field.t Tuple_lib.Double.t, 'a) Vector.t
    end) in
    match Nat.compare Padded_length.n (Vector.length commitments) with
    | `Lte le ->
        Core_kernel.Type_equal.conv
          (Core_kernel.Type_equal.sym (L.lift (Nat.Max_type.le le)))
          (Vector.extend_front_exn commitments
             (Vector.length commitments)
             dummy )
    | `Gt gt ->
        Core_kernel.Type_equal.conv
          (Core_kernel.Type_equal.sym
             (L.lift
                (Nat.Max_type.ge
                   (Nat.gt_implies_gte Padded_length.n
                      (Vector.length commitments)
                      gt ) ) ) )
          (Vector.extend_front_exn commitments Padded_length.n dummy)

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
      (* The sponge states we would reach if we absorbed the padding challenges.
         The accumulator is padded (at the front) up to [max (2, n)] vectors, so
         the number of padding challenges absorbed is [max (0, 2 - n)]. *)
      let s = Sponge.create sponge_params in
      let num_padding = Int.max 0 (2 - Nat.to_int max_proofs_verified) in
      let state, sponge_state =
        (Lazy.force dummy_messages_for_next_wrap_proof_sponge_states).(num_padding)
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
