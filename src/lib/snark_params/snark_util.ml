open Core_kernel

module Make (Impl : Snarky_backendless.Snark_intf.S) = struct
  open Impl
  open Let_syntax

  let pack_int bs =
    assert (List.length bs < 62) ;
    let rec go pt acc = function
      | [] ->
          acc
      | b :: bs ->
          if b then go (2 * pt) (pt + acc) bs else go (2 * pt) acc bs
    in
    go 1 0 bs

  let boolean_assert_lte (x : Boolean.var) (y : Boolean.var) =
    (*
      x <= y
      y == 1 or x = 0
      (y - 1) * x = 0
    *)
    assert_r1cs
      Field.Var.(sub (y :> Field.Var.t) (constant Field.one))
      (x :> Field.Var.t)
      (Field.Var.constant Field.zero)

  let assert_decreasing : Boolean.var list -> unit Checked.t =
    let rec go prev (bs0 : Boolean.var list) =
      match bs0 with
      | [] ->
          return ()
      | b :: bs ->
          let%bind () = boolean_assert_lte b prev in
          go b bs
    in
    function [] -> return () | b :: bs -> go b bs

  let nth_bit x ~n = (x lsr n) land 1 = 1

  let apply_mask mask bs = Checked.all (List.map2_exn mask bs ~f:Boolean.( && ))

  let pack_unsafe (bs0 : Boolean.var list) =
    let n = List.length bs0 in
    assert (n <= Field.size_in_bits) ;
    let rec go acc two_to_the_i = function
      | b :: bs ->
          go
            (Field.Var.add acc (Field.Var.scale b two_to_the_i))
            (Field.add two_to_the_i two_to_the_i)
            bs
      | [] ->
          acc
    in
    go (Field.Var.constant Field.zero) Field.one (bs0 :> Field.Var.t list)

  type _ Snarky_backendless.Request.t +=
    | N_ones : bool list Snarky_backendless.Request.t

  let n_ones ~total_length n =
    let%bind bs =
      exists
        (Typ.list ~length:total_length Boolean.typ)
        ~request:(As_prover.return N_ones)
        ~compute:
          As_prover.(
            map (read_var n) ~f:(fun n ->
                List.init total_length ~f:(fun i ->
                    Bigint.(
                      compare (of_field (Field.of_int i)) (of_field n) < 0) ) ))
    in
    let%map () =
      Field.Checked.Assert.equal
        (Field.Var.sum (bs :> Field.Var.t list))
        (* This can't overflow since the field is huge *)
        n
    and () = assert_decreasing bs in
    bs

  let assert_num_bits_upper_bound bs u =
    let total_length = List.length bs in
    assert (total_length < Field.size_in_bits) ;
    let%bind mask = n_ones ~total_length u in
    let%bind masked = apply_mask mask bs in
    with_label __LOC__ (fun () ->
        Field.Checked.Assert.equal (pack_unsafe masked) (pack_unsafe bs) )

  let num_bits_int =
    let rec go acc n = if n = 0 then acc else go (1 + acc) (n lsr 1) in
    go 0

  let size_in_bits_size_in_bits = num_bits_int Field.size_in_bits

  type _ Snarky_backendless.Request.t +=
    | Num_bits_upper_bound : Field.t Snarky_backendless.Request.t

  let num_bits_upper_bound_unchecked x =
    let num_bits =
      match
        List.find_mapi
          (List.rev (Field.unpack x))
          ~f:(fun i x -> if x then Some i else None)
      with
      | Some leading_zeroes ->
          Field.size_in_bits - leading_zeroes
      | None ->
          0
    in
    num_bits

  (* Someday: this could definitely be made more efficient *)
  let num_bits_upper_bound_unpacked : Boolean.var list -> Field.Var.t Checked.t
      =
   fun x_unpacked ->
    let%bind res =
      exists Typ.field
        ~request:(As_prover.return Num_bits_upper_bound)
        ~compute:
          As_prover.(
            map
              (read_var (Field.Var.project x_unpacked))
              ~f:(fun x -> Field.of_int (num_bits_upper_bound_unchecked x)))
    in
    let%map () = assert_num_bits_upper_bound x_unpacked res in
    res

  let num_bits_upper_bound ~max_length (x : Field.Var.t) : Field.Var.t Checked.t
      =
    Field.Checked.unpack x ~length:max_length >>= num_bits_upper_bound_unpacked
end
