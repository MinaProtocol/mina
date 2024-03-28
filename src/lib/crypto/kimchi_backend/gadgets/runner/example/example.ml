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
let example ~valid_witness () =
  let _proof_keypair, _proof =
    generate_and_verify_proof (fun () ->
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
  ()

(* Generate a proof with a valid witness. *)
let () = example ~valid_witness:true ()

(* Sanity-check: ensure that the proof with an invalid witness fails. *)
let () =
  let test_failed =
    try
      example ~valid_witness:false () ;
      false
    with _ -> true
  in
  assert test_failed
