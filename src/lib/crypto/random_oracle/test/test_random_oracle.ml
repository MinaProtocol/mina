(** Testing
    -------

    Component: Random_oracle
    Subject: Test iterativeness and checked-unchecked consistency
    Invocation: \
     dune exec src/lib/crypto/random_oracle/test/test_random_oracle.exe
*)

let field_testable =
  let open Pickles.Impls.Step.Internal_Basic in
  Alcotest.testable
    (fun fmt f -> Format.pp_print_string fmt (Field.to_string f))
    Field.equal

let state_testable = Alcotest.array field_testable

let test_iterativeness () =
  let open Pickles.Impls.Step.Internal_Basic in
  let x1 = Field.random () in
  let x2 = Field.random () in
  let x3 = Field.random () in
  let x4 = Field.random () in
  let s_full =
    Random_oracle.update ~state:Random_oracle.initial_state [| x1; x2; x3; x4 |]
  in
  let s_it =
    Random_oracle.update
      ~state:
        (Random_oracle.update ~state:Random_oracle.initial_state [| x1; x2 |])
      [| x3; x4 |]
  in
  Alcotest.check state_testable "state equality"
    (Random_oracle.State.to_array s_full)
    (Random_oracle.State.to_array s_it)

let test_sponge_checked_unchecked () =
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let x = T.Field.random () in
  let y = T.Field.random () in
  T.Test.test_equal ~equal:T.Field.equal ~sexp_of_t:T.Field.sexp_of_t
    T.Typ.(field * field)
    T.Typ.field
    (fun (x, y) ->
      make_checked (fun () -> Random_oracle.Checked.hash [| x; y |]) )
    (fun (x, y) -> Random_oracle.hash [| x; y |])
    (x, y)

let () =
  let open Alcotest in
  run "Random_oracle"
    [ ( "hash"
      , [ test_case "iterativeness" `Quick test_iterativeness
        ; test_case "sponge checked-unchecked" `Quick
            test_sponge_checked_unchecked
        ] )
    ]
