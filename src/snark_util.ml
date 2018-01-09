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

  let compare ~length a b =
    let alpha_packed =
      let open Cvar.Infix in
      Cvar.constant (two_to_the length) + b - a
    in
    let%bind alpha = Checked.unpack alpha_packed ~length:(length + 1) in
    let (prefix, less_or_equal) =
      match List.split_n alpha length with
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


