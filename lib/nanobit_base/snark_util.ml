open Core_kernel

module Make (Impl : Camlsnark.Snark_intf.S) = struct
  open Impl
  open Let_syntax

  let two_to_the n =
    let rec go acc i =
      if i = 0
      then acc
      else go Field.Infix.(acc + acc) (i - 1)
    in
    go Field.one n

  type comparison_result =
    { less : Boolean.var
    ; less_or_equal : Boolean.var
    }

  let compare ~bit_length a b =
    with_label "Snark_util.compare" begin
      let alpha_packed =
        let open Cvar.Infix in
        Cvar.constant (two_to_the bit_length) + b - a
      in
      let%bind alpha = Checked.unpack alpha_packed ~length:(bit_length + 1) in
      let (prefix, less_or_equal) =
        match List.split_n alpha bit_length with
        | (p, [l]) -> (p, l)
        | _ -> failwith "compare: Invalid alpha"
      in
      let%bind not_all_zeros = Boolean.any prefix in
      let%map less = Boolean.(less_or_equal && not_all_zeros) in
      { less; less_or_equal }
    end

  let random_n_bit_field_elt n =
    Field.project (List.init n ~f:(fun _ -> Random.bool ()))

  let%test_unit "compare" =
    let bit_length = Field.size_in_bits - 2 in
    let random () = random_n_bit_field_elt bit_length in
    let test () =
      let x = random () in
      let y = random () in
      let ((), (less, less_or_equal), passed) =
        run_and_check
          (let%map { less; less_or_equal } =
             compare ~bit_length (Cvar.constant x) (Cvar.constant y)
           in
           As_prover.(
             map2 (read Boolean.spec less) (read Boolean.spec less_or_equal)
               ~f:Tuple2.create))
          ()
      in
      assert passed;
      let r = Bigint.(compare (of_field x) (of_field y)) in
      assert (less = (r < 0));
      assert (less_or_equal = (r <= 0))
    in
    for i = 0 to 100 do
      test ()
    done

  module Assert = struct
    let lt ~bit_length x y =
      let%bind { less; _ } = compare ~bit_length x y in
      Boolean.Assert.is_true less

    let lte ~bit_length x y =
      let%bind { less_or_equal; _ } = compare ~bit_length x y in
      Boolean.Assert.is_true less_or_equal

    let gt ~bit_length x y = lt ~bit_length y x
    let gte ~bit_length x y = lte ~bit_length y x
  end

  let pack_int bs =
    assert (List.length bs < 62);
    let rec go pt acc = function
      | [] -> acc
      | b :: bs ->
        if b
        then go (2 * pt) (pt + acc) bs
        else go (2 * pt) acc bs
    in
    go 1 0 bs
  ;;

  let boolean_assert_lte (x : Boolean.var) (y : Boolean.var) =
    (*
      x <= y
      y == 1 or x = 0
      (y - 1) * x = 0
    *)
    assert_r1cs
      Cvar.(sub (y :> Cvar.t) (constant Field.one))
      (x :> Cvar.t)
      (Cvar.constant Field.zero)
  ;;

  let%test_unit "boolean_assert_lte" =
    assert (
      check
        (Checked.all_ignore
        [ boolean_assert_lte Boolean.false_ Boolean.false_ 
        ; boolean_assert_lte Boolean.false_ Boolean.true_
        ; boolean_assert_lte Boolean.true_ Boolean.true_
        ])
        ());
    assert (not (
      check
        (boolean_assert_lte Boolean.true_ Boolean.false_) ()))
  ;;

  let assert_decreasing : Boolean.var list -> (unit, _) Checked.t =
    let rec go prev (bs0 : Boolean.var list) =
      match bs0 with
      | [] -> return ()
      | b :: bs ->
        let%bind () = boolean_assert_lte b prev in
        go b bs
    in
    function
    | [] -> return ()
    | b :: bs -> go b bs
  ;;

  let%test_unit "assert_decreasing" =
    let decreasing bs = 
      check (assert_decreasing (List.map ~f:Boolean.var_of_value bs)) ()
    in
    assert (decreasing [true; true; true; false]);
    assert (decreasing [true; true; false; false]);
    assert (not (decreasing [true; true; false; true]));
  ;;

  let nth_bit x ~n = (x lsr n) land 1 = 1

  let apply_mask mask bs =
    Checked.all (List.map2_exn mask bs ~f:Boolean.(&&))

  let pack_unsafe (bs0 : Boolean.var list) =
    let n = List.length bs0 in
    assert (n <= Field.size_in_bits);
    let rec go acc two_to_the_i = function
      | b :: bs ->
        go Cvar.(add acc (scale b two_to_the_i))
          (Field.add two_to_the_i two_to_the_i)
          bs
      | [] -> acc
    in
    go (Cvar.constant Field.zero) Field.one (bs0 :> Cvar.t list)
  ;;

  type _ Camlsnark.Request.t +=
    | N_ones : bool list Camlsnark.Request.t

  let n_ones ~total_length n =
    let%bind bs =
      exists (Var_spec.list ~length:total_length Boolean.spec)
        ~request:(As_prover.return N_ones)
        ~compute:
          As_prover.(map (read_var n) ~f:(fun n ->
            List.init total_length ~f:(fun i ->
              Bigint.(compare (of_field (Field.of_int i)) (of_field n) < 0))))
    in
    let%map () =
      assert_equal
        (Cvar.sum (bs :> Cvar.t list)) (* This can't overflow since the field is huge *)
        n
    and () = assert_decreasing bs in
    bs

  let%test_unit "n_ones" =
    let total_length = 6 in
    let test n =
      let t = n_ones ~total_length (Cvar.constant (Field.of_int n)) in
      let handle_with (resp : bool list) = 
        handle t (fun (With {request; respond}) ->
          match request with
          | N_ones -> respond resp
          | _ -> unhandled)
      in
      let correct = Int.pow 2 n - 1 in
      let to_bits k = List.init total_length ~f:(fun i -> (k lsr i) land 1 = 1) in
      for i = 0 to Int.pow 2 total_length - 1 do
        if i = correct
        then assert (check (handle_with (to_bits i)) ())
        else assert (not (check (handle_with (to_bits i)) ()))
      done
    in
    for n = 0 to total_length do
      test n
    done
  ;;

  let assert_num_bits_upper_bound bs u =
    let total_length = List.length bs in
    assert (total_length < Field.size_in_bits);
    let%bind mask = n_ones ~total_length u in
    let%bind masked = apply_mask mask bs in
    assert_equal ~label:"Snark_util.assert_num_bits_upper_bound"
      (pack_unsafe masked) (pack_unsafe bs)

  let num_bits_int =
    let rec go acc n =
      if n = 0
      then acc
      else go (1 + acc) (n lsr 1)
    in
    go 0
  ;;

  let%test_unit "num_bits_int" =
    assert (num_bits_int 1 = 1);
    assert (num_bits_int 5 = 3);
    assert (num_bits_int 17 = 5);
  ;;

  let size_in_bits_size_in_bits = num_bits_int Field.size_in_bits

  type _ Camlsnark.Request.t +=
    | Num_bits_upper_bound : Field.t Camlsnark.Request.t

  let num_bits_upper_bound_unchecked x =
    let num_bits =
      match
        List.find_mapi (List.rev (Field.unpack x)) ~f:(fun i x ->
          if x then Some i else None)
      with
      | Some leading_zeroes -> Field.size_in_bits - leading_zeroes
      | None -> 0
    in
    num_bits

  let%test_unit "num_bits_upper_bound_unchecked" =
    let f k bs =
      assert (num_bits_upper_bound_unchecked (Field.project bs) = k)
    in
    f 3 [true; true; true; false; false];
    f 4 [true; true; true; true; false];
    f 3 [true; false; true; false; false];
    f 5 [true; false; true; false; true]
  ;;

  (* Someday: this could definitely be made more efficient *)
  let num_bits_upper_bound_unpacked : Boolean.var list -> (Cvar.t, _) Checked.t =
    fun x_unpacked ->
      let%bind res =
        exists Var_spec.field
          ~request:(As_prover.return Num_bits_upper_bound)
          ~compute:As_prover.(
            map (read_var (Checked.project x_unpacked))
              ~f:(fun x -> Field.of_int (num_bits_upper_bound_unchecked x)))
      in
      let%map () = assert_num_bits_upper_bound x_unpacked res in
      res
  ;;

  let num_bits_upper_bound ~max_length (x : Cvar.t) : (Cvar.t, _) Checked.t =
    Checked.unpack x ~length:max_length
    >>= num_bits_upper_bound_unpacked
  ;;

  let%test_unit "num_bits_upper_bound" =
    let max_length = Field.size_in_bits - 1 in
    let test x =
      let handle_with resp =
        handle
          (num_bits_upper_bound ~max_length (Cvar.constant x))
          (fun (With {request; respond}) ->
             match request with
             | Num_bits_upper_bound -> respond (Field.of_int resp)
             | _ -> unhandled)
      in
      let true_answer = num_bits_upper_bound_unchecked x in
      for i = 0 to true_answer - 1 do
        if check (handle_with i) ()
        then begin
          let n = Bigint.of_field x in
          failwithf !"Shouldn't have passed: x=%s, i=%d"
            (String.init max_length ~f:(fun j -> if Bigint.test_bit n j then '1' else '0'))
            i ();
        end;
      done;
      assert (check (handle_with true_answer) ())
    in
    test (random_n_bit_field_elt max_length)
  ;;
end
