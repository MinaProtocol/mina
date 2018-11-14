open Core_kernel
open Bitstring_lib

module Make (Impl : Snark_intf.S) = struct
  open Impl

  type t =
    {dimension: int; max_input_length: int; coefficients: Field.t list list}

  let create ~dimension ~max_input_length =
    { dimension
    ; max_input_length
    ; coefficients=
        List.init dimension ~f:(fun _ ->
            List.init max_input_length ~f:(fun _ -> Field.random ()) ) }

  let map2_lax xs ys ~f =
    let rec go acc xs ys =
      match (xs, ys) with
      | _, [] | [], _ -> List.rev acc
      | x :: xs, y :: ys -> go (f x y :: acc) xs ys
    in
    go [] xs ys

  let hash_to_field {dimension; max_input_length; coefficients} xs =
    let sum = List.fold ~init:Field.zero ~f:Field.add in
    List.map coefficients ~f:(fun cs ->
        sum (map2_lax cs xs ~f:(fun c b -> if b then c else Field.zero)) )

  let hash_to_bits t xs =
    let fs = hash_to_field t xs in
    List.concat_map fs ~f:(fun f ->
        let n = Bigint.of_field f in
        List.init Field.size_in_bits ~f:(fun i -> Bigint.test_bit n i) )

  module Checked = struct
    let hash_to_field ({dimension; max_input_length; coefficients} : t)
        (vs : Boolean.var list) : (Field.Checked.t list, _) Checked.t =
      let vs = (vs :> Field.Checked.t list) in
      let input_len = List.length vs in
      if input_len > max_input_length then
        failwithf "Input size %d exceeded max %d" input_len max_input_length () ;
      List.map coefficients ~f:(fun cs ->
          Field.Checked.linear_combination
            (map2_lax cs vs ~f:(fun c v -> (c, v))) )
      |> Checked.return

    let hash_to_bits (t : t) (vs : Boolean.var list) :
        (Boolean.var list, _) Checked.t =
      let open Let_syntax in
      let%bind xs = hash_to_field t vs in
      with_label "hash_to_bits"
        (let%map bss =
           Checked.all
             (List.map xs ~f:(Field.Checked.unpack ~length:Field.size_in_bits))
         in
         List.concat bss)
  end

  module Hash (M : sig
    val knapsack : t
  end) =
  struct
    open M

    type value = bool list [@@deriving sexp]

    type var = Boolean.var list

    let length = knapsack.dimension * Field.size_in_bits

    let typ : (var, value) Typ.t = Typ.list ~length Boolean.typ

    let typ_unchecked : (var, value) Typ.t =
      Typ.(list ~length Boolean.typ_unchecked)

    (* res = (1 - b) * xs + b * ys
     res - xs = b * (ys - xs)
  *)
    let if_ (b : Boolean.var) ~then_:ys ~else_:xs : (var, _) Impl.Checked.t =
      let open Impl.Let_syntax in
      let%bind res =
        provide_witness typ_unchecked
          (let open As_prover.Let_syntax in
          match%bind As_prover.read Boolean.typ b with
          | false -> As_prover.read typ xs
          | true -> As_prover.read typ ys)
      in
      let%map () =
        let open Field.Checked.Infix in
        assert_all
          (List.map3_exn
             (xs :> Field.Checked.t list)
             (ys :> Field.Checked.t list)
             (res :> Field.Checked.t list)
             ~f:(fun x y r ->
               Constraint.r1cs ~label:"Knapsack.Hash.if_"
                 (b :> Field.Checked.t)
                 (y - x) (r - x) ))
      in
      res

    let hash (h1 : var) (h2 : var) =
      with_label "Knapsack.hash" (Checked.hash_to_bits knapsack (h1 @ h2))

    let map2i_exn xs ys ~f =
      let rec go acc i xs ys =
        match (xs, ys) with
        | [], [] -> List.rev acc
        | x :: xs, y :: ys -> go (f i x y :: acc) (i + 1) xs ys
        | _, _ -> failwith "mapi_exn: Invalid lengths"
      in
      go [] 0 xs ys

    let assert_equal = Impl.Bitstring_checked.Assert.equal
  end
end
