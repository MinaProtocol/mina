let test_pow2pow_old_vs_new () =
  let module K = Step_main_inputs.Inner_curve in
  (*let rec pow2pow x i =
      if i = 0 then x else pow2pow K.Constant.(x + x) (i - 1)
    in
    let _res = pow2pow g 130 in*)
  let open K.Constant in
  let time_0 = Time.now () in
  let with_shift_old actual_shift =
    let rec pow2pow_old x i =
      if i = 0 then x else pow2pow_old K.Constant.(x + x) (i - 1)
    in

    for _j = 0 to 10 do
      let g = random () in
      let g = of_affine g in
      for _i = 0 to 1000 do
        let _h = pow2pow_old g actual_shift in
        ()
      done
    done
  in
  with_shift_old 130 ;
  with_shift_old 230 ;

  let time_1 = Time.now () in

  let with_shift_new actual_shift =
    (* computes 2^i *)
    let rec field2pow f i =
      if i = 1 then f
      else
        let j = i - 1 in
        K.Constant.Scalar.(f * field2pow f j)
    in
    (* computes 2^actual_shift *)
    let two_to_actual_shift =
      field2pow (K.Constant.Scalar.of_int 2) actual_shift
    in
    (* computes [2^actual_shift] G *)
    let field_to_two_to_shift g = K.Constant.scale g two_to_actual_shift in

    for _j = 0 to 10 do
      let g = random () in
      let g = of_affine g in
      for _i = 0 to 1000 do
        let _h = field_to_two_to_shift g in
        ()
      done
    done
  in
  with_shift_new 130 ;
  with_shift_new 230 ;

  let time_2 = Time.now () in

  printf
    !"test_pow2pow old: %f secs\n%!"
    (Time.Span.to_sec Time.(diff time_1 time_0)) ;
  printf
    !"test_pow2pow new: %f secs\n%!"
    (Time.Span.to_sec Time.(diff time_2 time_1)) ;

  assert false

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
  assert false

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
  ; ( "Impls:Pow2powOldVsNew"
    , [ test_case "pow2pow is faster" `Quick test_pow2pow_old_vs_new ] )
  ]
