(** Testing
    -------
    Component: Kimchi gadgets test runner
    Subject: Testing proof generation and verification with valid/invalid witnesses
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/runner/tests/test_runner.exe
*)

open Kimchi_gadgets_test_runner.Runner

(* Initialize the SRS cache. Normally Mina does this for us, but we're not
   using the Mina stdlib.
*)
let () = Tick.Keypair.set_urs_info []

(* Trivial example. The valid_witness parameter determines whether we should
   provide a satisfying witness or not.

   Note that this adds more than 1 constraint, because there is an assertion in
   kimchi that there is more than 1 gate (which is probably an error).
*)
let example ?cs ~valid_witness () =
  let cs, _proof_keypair, _proof =
    generate_and_verify_proof ?cs (fun () ->
        let open Impl in
        (* Create a fresh snarky variable. *)
        let a =
          exists Field.typ ~compute:(fun () ->
              if valid_witness then Field.Constant.of_int 5
              else Field.Constant.of_int 4 )
        in
        (* Create a snarky constant. *)
        let b = Field.of_int 20 in
        (* Create a new snarky variable, equal to the square of a. *)
        let a_squared = Field.(a * a) in
        (* Create a new snarky variable, equal to the sum of a and b. *)
        let a_plus_b = Field.(a + b) in
        (* Create a boolean, which is true iff a_squared equal a_plus_b.
           Note that, under the hood, this creates an intermediate variable.
        *)
        let is_equal = Field.equal a_squared a_plus_b in
        (* Assert that the boolean is true. *)
        Boolean.Assert.is_true is_equal ;
        (* Assert equality directly via the permutation argument. *)
        Field.Assert.equal a_squared a_plus_b )
  in
  cs

let test_proof_with_valid_witness () =
  let _cs = example ~valid_witness:true () in
  ()

let test_proof_with_invalid_witness_fails () =
  Alcotest.check_raises "Proof with invalid witness should fail"
    (Failure "Proof verification failed") (fun () ->
      try
        let _cs = example ~valid_witness:false () in
        ()
      with _ -> raise (Failure "Proof verification failed") )

let () =
  let open Alcotest in
  run "Kimchi gadgets test runner"
    [ ( "Proof generation and verification"
      , [ test_case "Proof with valid witness succeeds" `Quick
            test_proof_with_valid_witness
        ; test_case "Proof with invalid witness fails" `Quick
            test_proof_with_invalid_witness_fails
        ] )
    ]
