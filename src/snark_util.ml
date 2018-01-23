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
    with_label "Snark_uttil.compare" begin
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

  module Assert = struct
    let mem x xs =
      let length = List.length xs in
      let%bind bs =
        store (Var_spec.list ~length Boolean.spec) As_prover.(Let_syntax.(
          let%map x = read_var x
          and xs = As_prover.all (List.map ~f:read_var xs)
          in
          match List.findi xs ~f:(fun _ y -> Field.equal x y) with
          | None -> failwith "Snark_util.Assert.mem: Not found in list"
          | Some (i, _) ->
            List.init length ~f:(fun j -> j = i)))
      in
      let%bind () = Checked.Assert.exactly_one bs in
      let%bind ys =
        Checked.all (List.map2_exn ~f:(fun x b -> Checked.mul x (b :> Cvar.t)) xs bs)
      in
      assert_equal (Cvar.sum ys) x
  end

  let pow b (e : Boolean.var list) = failwith "TODO"
  ;;

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

  let assert_decreasing : Boolean.var list -> (unit, _) Checked.t =
    let rec go prev (bs0 : Boolean.var list) =
      match bs0 with
      | [] -> return ()
      | b :: bs ->
        let b = (b :> Cvar.t) in
        let%bind () =
          (*
             b <= prev
             prev == 1 or b = 0
            (prev - 1) * b = 0
          *)
          assert_r1cs
            Cvar.(sub prev (constant Field.one))
            b
            (Cvar.constant Field.zero)
        in
        go b bs
    in
    function
    | [] -> return ()
    | b :: bs -> go (b :> Cvar.t) bs
  ;;

  let num_bits_int =
    let rec go acc n =
      if n = 0
      then acc
      else go (1 + acc) (n lsr 1)
    in
    go 0
  ;;

  let apply_mask mask bs =
    Checked.all (List.map2_exn mask bs ~f:Boolean.(&&))

  let bit_length_bit_length = num_bits_int Field.size_in_bits
  ;;

  (* Someday: this could definitely be made more efficient *)
  let num_bits : Cvar.t -> (Cvar.t, _) Checked.t =
    let max = Field.size_in_bits in
    let rec n_ones n =
      let%bind bs =
        store (Var_spec.list ~length:max Boolean.spec)
          As_prover.(map (all (List.map ~f:(read Boolean.spec) n)) ~f:(fun n ->
            let n = pack_int n in
            List.init max ~f:(fun i -> i < n)))
      in
      let%map () = assert_equal (Cvar.sum (bs :> Cvar.t list)) (Checked.pack n)
      and () = assert_decreasing bs in
      bs
    in
    fun x ->
      let%bind res =
        store (Var_spec.list ~length:bit_length_bit_length Boolean.spec) (failwith "TODO")
      in
      let%bind mask = n_ones res in
      let%bind x_unpacked = Checked.unpack x ~length:Field.size_in_bits in
      let%bind masked = apply_mask mask x_unpacked in
      let%map () = assert_equal (Checked.pack masked) x in
      Checked.pack res
  ;;

  let compare_field x y =
    let nx = Bigint.of_field x in
    let ny = Bigint.of_field y in
    let rec go i =
      if i < 0
      then 0
      else
        match Bigint.test_bit nx i, Bigint.test_bit ny i with
        | true, true | false, false -> go (i - 1)
        | true, false -> 1
        | false, true -> -1
    in
    go (Field.size_in_bits - 1)

  let median_split length =
    let k = length / 2 in
    let r = length mod 2 in
    (`Less_equal (k + r), `Greater_equal k)
  ;;

  let int_log2 =
    let rec go acc n =
      if n = 0
      then acc
      else go (1 + acc) (n lsr 1)
    in
    go 0
  ;;

  let median ~bit_length (xs : Cvar.t list) =
    let length = List.length xs in
    let length_bit_length = int_log2 length in
    let assert_gte x y =
    (* TODO: Save a constraint by doing a comparison that doesn't bother computing [less] from [less_or_equal] like [compare] does. *)
      let%bind { less_or_equal; _ } =
        compare ~bit_length:length_bit_length (Cvar.constant (Field.of_int y)) x
      in
      Boolean.Assert.is_true less_or_equal
    in
    let (`Less_equal le, `Greater_equal ge) = median_split length in
    let index = le - 1 in
    let%bind m =
      store Var_spec.field As_prover.(Let_syntax.(
        let%map xs = read Var_spec.(list ~length field) xs in
        let xs = List.sort ~cmp:compare_field xs in
        List.nth_exn xs index))
    in
    let%bind cs = Checked.all (List.map ~f:(compare ~bit_length m) xs) in
    let le_count = Cvar.sum (List.map cs ~f:(fun c -> (c.less_or_equal :> Cvar.t))) in
    let ge_count = Cvar.sum (List.map cs ~f:(fun c -> (Boolean.not c.less :> Cvar.t))) in
    let%bind () =
      (* TODO: I think we can compute this more efficiently from the comparison results *)
      Checked.all (List.map xs ~f:(fun x -> Checked.equal x m))
      >>= Checked.Assert.any
    in
    let%map () = assert_gte le_count le
    and () = assert_gte ge_count ge
    in
    m
  ;;
end
