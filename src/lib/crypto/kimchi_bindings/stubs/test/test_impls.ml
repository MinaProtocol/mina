let test_pow2pow_slow () =
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

let test_pow2pow_fast () =
  (*let module K = Step_main_inputs.Inner_curve in*)
  let module K = Pasta_bindings.Pallas in
  (*let rec pow2pow x i =
      if i = 0 then x else pow2pow K.Constant.(x + x) (i - 1)
    in
    let _res = pow2pow g 130 in*)
  (*let open K.Constant in*)
  let open K in
  let time_0 = Time.now () in
  let g = random () in
  (*let g = of_affine g in*)
  for _i = 0 to 10000 do
    let _h =
      K.(add g @@ add g @@ add g @@ add g @@ add g @@ add g @@ add g g)
    in
    ()
  done ;
  let time_1 = Time.now () in
  printf
    !"test_pow2pow: %f secs\n%!"
    (Time.Span.to_sec Time.(diff time_1 time_0)) ;
  assert true

let test_negate_slow () =
  let module K = Step_main_inputs.Inner_curve in
  let open K.Constant in
  let time_0 = Time.now () in
  let g = random () in
  (*let g = of_affine g in*)
  for _i = 0 to 10000 do
    let _h =
      K.Constant.(
        negate @@ negate @@ negate @@ negate @@ negate @@ negate @@ negate g)
    in
    ()
  done ;
  let time_1 = Time.now () in
  printf
    !"test_negate: %f secs\n%!"
    (Time.Span.to_sec Time.(diff time_1 time_0)) ;
  assert false

let test_negate_fast () =
  let module K = Pasta_bindings.Pallas in
  let open K in
  let time_0 = Time.now () in
  let g = random () in
  (*let g = of_affine g in*)
  for _i = 0 to 10000 do
    let _h =
      K.(negate @@ negate @@ negate @@ negate @@ negate @@ negate @@ negate g)
    in
    ()
  done ;
  let time_1 = Time.now () in
  printf
    !"test_negate: %f secs\n%!"
    (Time.Span.to_sec Time.(diff time_1 time_0)) ;
  assert true

let tests =
  let open Alcotest in
  [ ( "Impls:Pow2powFast"
    , [ test_case "pow2pow works fast" `Quick test_pow2pow_fast ] )
  ; ( "Impls:Pow2powSlow"
    , [ test_case "pow2pow works fast" `Quick test_pow2pow_slow ] )
  ; ( "Impls:NegateFast"
    , [ test_case "negate works fast" `Quick test_negate_fast ] )
  ; ( "Impls:NegateSlow"
    , [ test_case "negate works fast" `Quick test_negate_slow ] )
  ]
