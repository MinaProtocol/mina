(* Testing
   -------

   Component: Pickles
   Subject: Test step and wrap circuits
   Invocation: dune exec src/lib/pickles/test/main.exe -- test "Impls:"
*)

let test_step_circuit_behavior () =
  let expected_list =
    [ ("45560315531506369815346746415080538112", false)
    ; ("45560315531506369815346746415080538113", false)
    ; ( "14474011154664524427946373126085988481727088556502330059655218120611762012161"
      , true )
    ; ( "14474011154664524427946373126085988481727088556502330059655218120611762012161"
      , true )
    ]
  in
  let str_list =
    List.map (Lazy.force Impls.Step.Other_field.forbidden_shifted_values)
      ~f:(fun (a, b) -> (Backend.Tick.Field.to_string a, b))
  in
  assert ([%equal: (string * bool) list] str_list expected_list)

let test_wrap_circuit_behavior () =
  let expected_list =
    [ "91120631062839412180561524743370440705"
    ; "91120631062839412180561524743370440706"
    ]
  in
  let str_list =
    List.map
      (Lazy.force Impls.Wrap.Other_field.forbidden_shifted_values)
      ~f:Backend.Tock.Field.to_string
  in
  assert ([%equal: string list] str_list expected_list)

let tests =
  let open Alcotest in
  [ ( "Impls:Step"
    , [ test_case "preserve circuit behavior" `Quick test_step_circuit_behavior
      ] )
  ; ( "Impls:Wrap"
    , [ test_case "preserve circuit behavior" `Quick test_wrap_circuit_behavior
      ] )
  ]
