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

let test_pow2pow () =
  let module K = Step_main_inputs.Inner_curve in
  (*let rec pow2pow x i =
      if i = 0 then x else pow2pow K.Constant.(x + x) (i - 1)
    in
    let _res = pow2pow g 130 in*)
  let open K.Constant in
  let time_0 = Time.now () in
  let g = random () in
  let g = of_affine g in
  for _i = 0 to 10000 do
    let _h = K.Constant.(g + g + g + g + g + g + g + g) in
    ()
  done ;
  let time_1 = Time.now () in
  printf
    !"test_pow2pow: %f secs\n%!"
    (Time.Span.to_sec Time.(diff time_1 time_0)) ;
  assert false

let tests =
  let open Alcotest in
  [ ( "Impls:Step"
    , [ test_case "preserve circuit behavior" `Quick test_step_circuit_behavior
      ] )
  ; ( "Impls:Wrap"
    , [ test_case "preserve circuit behavior" `Quick test_wrap_circuit_behavior
      ] )
  ; ("Impls:Pow2pow", [ test_case "pow2pow works fast" `Quick test_pow2pow ])
  ]
