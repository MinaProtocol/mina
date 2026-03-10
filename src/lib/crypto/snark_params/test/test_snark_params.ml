open Core_kernel
open Snark_params

(* Test from snark_params.ml *)
let group_map_test () =
  let params = Crypto_params.Tock.group_map_params () in
  let module M = Crypto_params.Tick.Run in
  Quickcheck.test ~trials:3 Tick.Field.gen ~f:(fun t ->
      let checked_output =
        M.run_and_check (fun () ->
            let x, y =
              Snarky_group_map.Checked.to_group
                (module M)
                ~params (M.Field.constant t)
            in
            fun () -> M.As_prover.(read_var x, read_var y) )
        |> Or_error.ok_exn
      in
      let ((x, y) as actual) = Group_map.to_group t in
      Alcotest.(check bool)
        "curve equation" true
        Tick.Field.(
          equal
            ( (x * x * x)
            + (Tick.Inner_curve.Params.a * x)
            + Tick.Inner_curve.Params.b )
            (y * y)) ;
      let actual_x, actual_y = actual in
      let checked_x, checked_y = checked_output in
      Alcotest.(check bool)
        "x coordinates match" true
        (Tick.Field.equal actual_x checked_x) ;
      Alcotest.(check bool)
        "y coordinates match" true
        (Tick.Field.equal actual_y checked_y) )

(* Utility functions for snark_util tests *)
module Test_util = struct
  let random_bitstring length = List.init length ~f:(fun _ -> Random.bool ())

  let random_n_bit_field_elt n = Tick.Field.project (random_bitstring n)
end

(* Tests from snark_util.ml *)
let compare_test () =
  Random.init 123456789 ;
  let bit_length = Tick.Field.size_in_bits - 2 in
  let random () = Test_util.random_n_bit_field_elt bit_length in
  let test () =
    let x = random () in
    let y = random () in
    let less, less_or_equal =
      let open Tick.Checked.Let_syntax in
      Tick.run_and_check
        (let%map { less; less_or_equal } =
           Tick.Field.Checked.compare ~bit_length
             (Tick.Field.Var.constant x)
             (Tick.Field.Var.constant y)
         in
         Tick.As_prover.(
           map2
             (read Tick.Boolean.typ less)
             (read Tick.Boolean.typ less_or_equal)
             ~f:Tuple2.create) )
      |> Or_error.ok_exn
    in
    let r = Tick.Bigint.(compare (of_field x) (of_field y)) in
    Alcotest.(check bool) "less comparison" (r < 0) less ;
    Alcotest.(check bool) "less_or_equal comparison" (r <= 0) less_or_equal
  in
  for _i = 0 to 100 do
    test ()
  done

let boolean_assert_lte_test () =
  let module U = Tick.Util in
  Or_error.ok_exn
    (Tick.check
       (Tick.Checked.all_unit
          [ U.boolean_assert_lte Tick.Boolean.false_ Tick.Boolean.false_
          ; U.boolean_assert_lte Tick.Boolean.false_ Tick.Boolean.true_
          ; U.boolean_assert_lte Tick.Boolean.true_ Tick.Boolean.true_
          ] ) ) ;
  Alcotest.(check bool)
    "invalid assertion should fail" true
    (Or_error.is_error
       (Tick.check
          (U.boolean_assert_lte Tick.Boolean.true_ Tick.Boolean.false_) ) )

let assert_decreasing_test () =
  let module U = Tick.Util in
  let decreasing bs =
    Tick.check (U.assert_decreasing (List.map ~f:Tick.Boolean.var_of_value bs))
  in
  Or_error.ok_exn (decreasing [ true; true; true; false ]) ;
  Or_error.ok_exn (decreasing [ true; true; false; false ]) ;
  Alcotest.(check bool)
    "increasing should fail" true
    (Or_error.is_error (decreasing [ true; true; false; true ]))

let n_ones_test () =
  let module U = Tick.Util in
  let total_length = 6 in
  let test n =
    let t () =
      U.n_ones ~total_length (Tick.Field.Var.constant (Tick.Field.of_int n))
    in
    let handle_with (resp : bool list) =
      Tick.handle t (fun (Tick.With { request; respond }) ->
          match request with
          | U.N_ones ->
              respond (Provide resp)
          | _ ->
              Tick.unhandled )
    in
    let correct = Int.pow 2 n - 1 in
    let to_bits k = List.init total_length ~f:(fun i -> (k lsr i) land 1 = 1) in
    for i = 0 to Int.pow 2 total_length - 1 do
      if i = correct then Or_error.ok_exn (Tick.check (handle_with (to_bits i)))
      else
        Alcotest.(check bool)
          (sprintf "should fail for i=%d, n=%d" i n)
          true
          (Or_error.is_error (Tick.check (handle_with (to_bits i))))
    done
  in
  for n = 0 to total_length do
    test n
  done

let num_bits_int_test () =
  let module U = Tick.Util in
  Alcotest.(check int) "num_bits_int 1" 1 (U.num_bits_int 1) ;
  Alcotest.(check int) "num_bits_int 5" 3 (U.num_bits_int 5) ;
  Alcotest.(check int) "num_bits_int 17" 5 (U.num_bits_int 17)

let num_bits_upper_bound_unchecked_test () =
  let module U = Tick.Util in
  let f k bs =
    Alcotest.(check int)
      (sprintf "num_bits for %s"
         (String.of_char_list
            (List.map bs ~f:(fun b -> if b then '1' else '0')) ) )
      k
      (U.num_bits_upper_bound_unchecked (Tick.Field.project bs))
  in
  f 3 [ true; true; true; false; false ] ;
  f 4 [ true; true; true; true; false ] ;
  f 3 [ true; false; true; false; false ] ;
  f 5 [ true; false; true; false; true ]

let tests =
  [ ("group_map", `Quick, group_map_test)
  ; ("compare", `Quick, compare_test)
  ; ("boolean_assert_lte", `Quick, boolean_assert_lte_test)
  ; ("assert_decreasing", `Quick, assert_decreasing_test)
  ; ("n_ones", `Quick, n_ones_test)
  ; ("num_bits_int", `Quick, num_bits_int_test)
  ; ( "num_bits_upper_bound_unchecked"
    , `Quick
    , num_bits_upper_bound_unchecked_test )
  ]

let () =
  let open Alcotest in
  run "Snark_params" [ ("snark_tests", tests) ]
