open Core_kernel

(* Test for group-map from snark_params.ml *)
let test_group_map () =
  let params = Crypto_params.Tock.group_map_params () in
  let module M = Crypto_params.Tick.Run in
  Quickcheck.test ~trials:3 Snark_params.Tick0.Field.gen ~f:(fun t ->
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
      let (x, y) =
        Group_map.to_group (module Snark_params.Tick0.Field) ~params t
      in
      let left =
        Snark_params.Tick0.Field.(
          (x * x * x)
          + (Snark_params.Tick0.Inner_curve.Params.a * x)
          + Snark_params.Tick0.Inner_curve.Params.b)
      in
      let right = Snark_params.Tick0.Field.(y * y) in
      Alcotest.(check bool)
        "Field equation holds"
        true
        (Snark_params.Tick0.Field.equal left right);

      Alcotest.(check bool)
        "Checked output matches actual"
        true
        (Snark_params.Tick0.Field.equal (fst checked_output) x &&
         Snark_params.Tick0.Field.equal (snd checked_output) y))

(* Tests from snark_util.ml *)
module Random_helpers = struct
  let () = Random.init 123456789

  let random_bitstring length =
    List.init length ~f:(fun _ -> Random.bool ())

  let random_n_bit_field_elt n =
    Snark_params.Tick0.Field.project (random_bitstring n)
end

module Util_tests = struct
  open Snark_params.Tick0
  open Snark_params.Tick.Util

  let test_compare () =
    let bit_length = Field.size_in_bits - 2 in
    let random () = Random_helpers.random_n_bit_field_elt bit_length in
    for _ = 0 to 100 do
      let x = random () in
      let y = random () in
      let less, less_or_equal =
        run_and_check
          (let%map { less; less_or_equal } =
             Field.Checked.compare ~bit_length (Field.Var.constant x)
               (Field.Var.constant y)
           in
           As_prover.(
             map2 (read Boolean.typ less)
               (read Boolean.typ less_or_equal)
               ~f:Tuple2.create) )
        |> Or_error.ok_exn
      in
      let r = Bigint.(compare (of_field x) (of_field y)) in
      Alcotest.(check bool) "less is correct" (r < 0) less;
      Alcotest.(check bool) "less_or_equal is correct" (r <= 0) less_or_equal
    done

  let test_boolean_assert_lte () =
    (* Check that valid assertions pass *)
    let () =
      Or_error.ok_exn
        (check
           (Checked.all_unit
              [ boolean_assert_lte Boolean.false_ Boolean.false_
              ; boolean_assert_lte Boolean.false_ Boolean.true_
              ; boolean_assert_lte Boolean.true_ Boolean.true_
              ] ) )
    in
    let check_false =
      Or_error.is_error
        (check (boolean_assert_lte Boolean.true_ Boolean.false_))
    in
    Alcotest.(check unit) "Valid assertions pass" () ();
    Alcotest.(check bool) "Invalid assertion fails" true check_false

  let test_assert_decreasing () =
    let decreasing bs =
      check (assert_decreasing (List.map ~f:Boolean.var_of_value bs))
    in
    (* Valid test cases should pass *)
    ignore(Or_error.ok_exn (decreasing [ true; true; true; false ]));
    ignore(Or_error.ok_exn (decreasing [ true; true; false; false ]));

    let check_invalid = Or_error.is_error (decreasing [ true; true; false; true ]) in
    Alcotest.(check unit) "Valid decreasing 1 passes" () ();
    Alcotest.(check unit) "Valid decreasing 2 passes" () ();
    Alcotest.(check bool) "Invalid decreasing fails" true check_invalid

  let test_n_ones () =
    let total_length = 6 in
    let test n =
      let t () =
        n_ones ~total_length (Field.Var.constant (Field.of_int n))
      in
      let handle_with (resp : bool list) =
        handle t (fun (With { request; respond }) ->
            match request with
            | N_ones ->
                respond (Provide resp)
            | _ ->
                unhandled )
      in
      let correct = Int.pow 2 n - 1 in
      let to_bits k =
        List.init total_length ~f:(fun i -> (k lsr i) land 1 = 1)
      in
      for i = 0 to Int.pow 2 total_length - 1 do
        let is_ok = Or_error.is_ok (check (handle_with (to_bits i))) in
        let expected = i = correct in
        Alcotest.(check bool)
          (Printf.sprintf "n_ones check for i=%d n=%d" i n)
          expected is_ok
      done
    in
    for n = 0 to total_length do
      test n
    done

  let test_num_bits_int () =
    Alcotest.(check int) "num_bits_int 1" 1 (num_bits_int 1);
    Alcotest.(check int) "num_bits_int 5" 3 (num_bits_int 5);
    Alcotest.(check int) "num_bits_int 17" 5 (num_bits_int 17)

  let test_num_bits_upper_bound_unchecked () =
    let f k bs =
      let result = num_bits_upper_bound_unchecked (Field.project bs) in
      Alcotest.(check int)
        (Printf.sprintf "num_bits_upper_bound_unchecked for k=%d" k)
        k result
    in
    f 3 [ true; true; true; false; false ];
    f 4 [ true; true; true; true; false ];
    f 3 [ true; false; true; false; false ];
    f 5 [ true; false; true; false; true ]
end

let () =
  let open Alcotest in
  run "Snark_params"
    [ ( "group_map"
      , [ test_case "group_map test" `Quick test_group_map ])
    ; ( "snark_util"
      , [ test_case "compare" `Quick Util_tests.test_compare
        ; test_case "boolean_assert_lte" `Quick Util_tests.test_boolean_assert_lte
        ; test_case "assert_decreasing" `Quick Util_tests.test_assert_decreasing
        ; test_case "n_ones" `Quick Util_tests.test_n_ones
        ; test_case "num_bits_int" `Quick Util_tests.test_num_bits_int
        ; test_case "num_bits_upper_bound_unchecked" `Quick Util_tests.test_num_bits_upper_bound_unchecked
        ])
    ]
