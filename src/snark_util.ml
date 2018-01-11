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
  ;;

  type comparison_result =
    { less : Boolean.var
    ; less_or_equal : Boolean.var
    }

  let compare ~bit_length a b =
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
    let%bind not_all_zeros = Checked.any prefix in
    let%map less = Boolean.(less_or_equal && not_all_zeros) in
    { less; less_or_equal }
  ;;

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
    ;;
  end

  let pow b (e : Boolean.var list) = failwith "TODO"
  ;;

  let log2_upper_bound (v : Cvar.t) = failwith "TODO"
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
      Boolean.assert_ less_or_equal
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
    let eq_count =
      (* TODO: I think we can compute this more efficiently from the comparison results *)
      Checked.Assert.any
        (Checked.all (List.map xs ~f:(fun c -> Boolean.(c.less_or_equal 
    let%map () = assert_gte le_count le
    and () = assert_gte ge_count ge
    and () = 
    in
    m
  ;;

(* (#<=) >= n/2
   (#>=) >= n/2 *)
  let median
        ~bit_length
        (xs : Cvar.t list)
    =
    let length = List.length xs in
    let index = length / 2 in
    let _m =
      store Var_spec.field As_prover.(Let_syntax.(
        let%map xs = read Var_spec.(list ~length field) xs in
        let xs = List.sort ~cmp:compare_field xs in
        List.nth_exn xs index))
    in
    return (failwith "TODO")
(*
    let%bind () =
      List.map xs ~f:(fun 
*)

  ;;
end


