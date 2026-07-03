(** Testing
    -------

    Component: Pickles
    Subject: Test the packed layout of Branch_data
    Invocation: \
     dune exec src/lib/crypto/pickles/test/test_branch_data.exe
*)

open Pickles_types
module Branch_data = Composition_types.Branch_data
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl

let all_branch_data n =
  List.concat_map
    (List.init (Nat.to_int n + 1) ~f:Fn.id)
    ~f:(fun proofs_verified ->
      List.map [ 0; 1; 13; 16; 255 ] ~f:(fun d ->
          { Branch_data.proofs_verified
          ; domain_log2 = Branch_data.Domain_log2.of_int_exn d
          } ) )

(* [unpack (pack x) = x], and [pack] stays within [length_in_bits], which is
   how many bits of the packed public input get constrained. *)
let test_round_trip w () =
  let (Nat.T n) = Nat.of_int (w - 2) in
  let n = Nat.S (Nat.S n) in
  List.iter (all_branch_data n) ~f:(fun x ->
      let packed = Branch_data.pack (module Step_impl) n x in
      [%test_eq: Branch_data.t] x
        (Branch_data.unpack (module Step_impl) n packed) ;
      let bits = Step_impl.Field.Constant.unpack packed in
      List.iteri bits ~f:(fun i b ->
          if b then assert (i < Branch_data.length_in_bits n) ) )

(* The in-circuit packer agrees with the out-of-circuit one. *)
let test_checked_pack w () =
  let (Nat.T n) = Nat.of_int (w - 2) in
  let n = Nat.S (Nat.S n) in
  List.iter (all_branch_data n) ~f:(fun x ->
      Step_impl.Internal_Basic.Test.test_equal
        ~sexp_of_t:Step_impl.Field.Constant.sexp_of_t
        ~equal:Step_impl.Field.Constant.equal
        (Branch_data.typ ~assert_16_bits:(fun _ -> ()) n)
        Step_impl.Field.typ
        (fun t ->
          Step_impl.make_checked (fun () -> Branch_data.Checked.Step.pack t) )
        (Branch_data.pack (module Step_impl) n)
        x )

let () =
  let widths = List.init 5 ~f:(fun i -> i + 2) in
  let cases name f =
    List.map widths ~f:(fun w ->
        Alcotest.test_case (sprintf "%s width %d" name w) `Quick (f w) )
  in
  Alcotest.run "Branch_data"
    [ ( "Branch_data"
      , cases "round trip" test_round_trip
        @ cases "checked pack" test_checked_pack )
    ]
