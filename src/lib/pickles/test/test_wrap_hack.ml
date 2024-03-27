(* Testing
   -------

   Component: Pickles
   Subject: Test module Wrap_hack
   Invocation: \
    dune exec src/lib/pickles/test/main.exe -- test "Wrap hack"
*)

open Pickles_types
open Backend
module Wrap_main_inputs = Pickles__Wrap_main_inputs
module Wrap_hack = Pickles__Wrap_hack

(* Check that the pre-absorbing technique works. I.e., that it's consistent with
   the actual definition of hash_messages_for_next_wrap_proof. *)
let test_hash_messages_for_next_wrap_proof (type n) (n : n Nat.t) () =
  let open Pickles.Impls.Wrap in
  let messages_for_next_wrap_proof :
      _ Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.t =
    let g = Wrap_main_inputs.Inner_curve.Constant.random () in
    { Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof
      .challenge_polynomial_commitment = g
    ; old_bulletproof_challenges =
        Vector.init n ~f:(fun _ ->
            Vector.init Backend.Tock.Rounds.n ~f:(fun _ ->
                Tock.Field.random () ) )
    }
  in
  Internal_Basic.Test.test_equal ~sexp_of_t:Field.Constant.sexp_of_t
    ~equal:Field.Constant.equal
    (Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.typ
       Wrap_main_inputs.Inner_curve.typ
       (Vector.typ Field.typ Backend.Tock.Rounds.n)
       ~length:n )
    Field.typ
    (fun t ->
      make_checked (fun () ->
          Wrap_hack.Checked.hash_messages_for_next_wrap_proof n t ) )
    (fun t ->
      Wrap_hack.Checked.hash_constant_messages_for_next_wrap_proof n t
      |> Digest.Constant.to_bits |> Impls.Wrap.Field.Constant.project )
    messages_for_next_wrap_proof

let tests =
  let open Alcotest in
  [ ( "Wrap hack"
    , [ test_case "hash_messages_for_next_wrap_proof correct 0" `Quick
          (test_hash_messages_for_next_wrap_proof Nat.N0.n)
      ; test_case "hash_messages_for_next_wrap_proof correct 1" `Quick
          (test_hash_messages_for_next_wrap_proof Nat.N1.n)
      ; test_case "hash_messages_for_next_wrap_proof correct 2" `Quick
          (test_hash_messages_for_next_wrap_proof Nat.N2.n)
      ] )
  ]
