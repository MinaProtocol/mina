(** Invocation: 
    dune exec src/lib/pickles_base/test/main.exe -- test "Side loaded verification key"
 *)

let test_eq_max_branches () =
  let open Pickles_base.Side_loaded_verification_key in
  [%test_eq: int]
    (Pickles_types.Nat.to_int Max_branches.n)
    (1 lsl Pickles_types.Nat.to_int Max_branches.Log2.n)

let tests =
  let open Alcotest in
  [ ( "Side loaded verification key"
    , [ test_case "check max branches" `Quick test_eq_max_branches ] )
  ]
