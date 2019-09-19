open Core
module State = Array
module Input = Input

let params : _ Sponge.Params.t =
  let open Crypto_params.Rescue_params in
  {mds; round_constants}

module Field = Crypto_params.Tick0.Field

let pack_input ~project {Input.field_elements; bitstrings} =
  let packed_bits =
    let xs, final, len_final =
      Array.fold bitstrings ~init:([], [], 0)
        ~f:(fun (acc, curr, n) bitstring ->
          let k = List.length bitstring in
          let n' = k + n in
          if n' >= Field.size_in_bits then (project curr :: acc, bitstring, k)
          else (acc, bitstring @ curr, n') )
    in
    if len_final = 0 then xs else project final :: xs
  in
  Array.append field_elements (Array.of_list_rev packed_bits)

module Inputs = struct
  module Field = Field

  let to_the_alpha x =
    let open Field in
    let res = x + zero in
    res *= res ;
    (* x^2 *)
    res *= res ;
    (* x^4 *)
    res *= x ;
    (* x^5 *)
    res *= res ;
    (* x^10 *)
    res *= x ;
    res

  module Operations = struct
    let apply_matrix rows v =
      Array.map rows ~f:(fun row ->
          let open Field in
          let res = zero + zero in
          Array.iteri row ~f:(fun i r -> res += (r * v.(i))) ;
          res )

    let add_block ~state block =
      Array.iteri block ~f:(fun i b ->
          let open Field in
          state.(i) += b )

    (* TODO: Have an explicit function for making a copy of a field element. *)
    let copy a = Array.map a ~f:(fun x -> Field.(x + zero))
  end

  let _alphath_root =
    let inv_alpha =
      Bigint.of_string Crypto_params.Rescue_params.inv_alpha
      |> Bigint.to_zarith_bigint
    in
    let k = 4 in
    let chunks = (Crypto_params.Tick0.Field.size_in_bits + (k - 1)) / k in
    let inv_alpha =
      let chunk i =
        let b j = Z.testbit inv_alpha ((k * i) + j) in
        Sequence.fold ~init:0
          (Sequence.range ~start:`inclusive ~stop:`exclusive 0 k)
          ~f:(fun acc i -> acc + ((1 lsl i) * Bool.to_int (b i)))
      in
      (* High bits first *)
      Array.init chunks ~f:(fun i -> chunk (chunks - 1 - i))
    in
    let lookup_table x =
      let n = 1 lsl k in
      let arr = Array.init (1 lsl k) ~f:(fun _ -> Field.one) in
      for i = 1 to n - 1 do
        arr.(i) <- Field.( * ) x arr.(i - 1)
      done ;
      arr
    in
    fun x ->
      let tbl = lookup_table x in
      Array.fold inv_alpha ~init:Field.one ~f:(fun acc chunk ->
          Field.( * ) (Fn.apply_n_times ~n:k Field.square acc) tbl.(chunk) )

  let%test_unit "alpha_root" =
    let x = Field.random () in
    let root = _alphath_root x in
    [%test_eq: Field.t] (to_the_alpha root) x
end

module Digest = struct
  open Crypto_params.Tick0.Field

  type nonrec t = t

  let to_bits ?length x =
    match length with
    | None ->
        unpack x
    | Some length ->
        List.take (unpack x) length
end

include Sponge.Make(Sponge.Poseidon (Inputs))

let update ~state = update ~state params

let hash ?init = hash ?init params

module Checked = struct
  open Crypto_params.Runners.Tick

  module Inputs = struct
    module Field = Field

    let to_the_alpha x =
      let open Field in
      let zero = square in
      let one a = square a * x in
      let one' = x in
      one' |> zero |> one |> one

    let _alphath_root x =
      let open Field in
      let y =
        exists typ ~compute:(fun () ->
            Inputs._alphath_root (As_prover.read typ x) )
      in
      let y10 = y |> square |> square |> ( * ) y |> square in
      assert_r1cs y10 y x ; y

    module Operations = Sponge.Make_operations(Field)
  end

  module Digest = struct
    open Field

    type nonrec t = t

    let to_bits ?(length = Field.size_in_bits) x =
      List.take (choose_preimage_var ~length:Field.size_in_bits x) length
  end

  include Sponge.Make (Sponge.Poseidon(Inputs))

  let params =
    Sponge.Params.map ~f:Crypto_params.Tick0.Field.Var.constant params

  let update = update params

  let hash ?init =
    hash ?init:(Option.map init ~f:(State.map ~f:Field.constant)) params

  let pack_input = pack_input ~project:Field.project
end

let pack_input = pack_input ~project:Field.project

let%test_unit "iterativeness" =
  let open Crypto_params.Tick0 in
  let x1 = Field.random () in
  let x2 = Field.random () in
  let x3 = Field.random () in
  let x4 = Field.random () in
  let s_full = update ~state:initial_state [|x1; x2; x3; x4|] in
  let s_it =
    update ~state:(update ~state:initial_state [|x1; x2|]) [|x3; x4|]
  in
  [%test_eq: Field.t array] s_full s_it

let%test_unit "sponge" =
  let module T = Crypto_params.Tick0 in
  let x = T.Field.random () in
  let y = T.Field.random () in
  T.Test.test_equal ~equal:T.Field.equal ~sexp_of_t:T.Field.sexp_of_t
    T.Typ.(field * field)
    T.Typ.field
    (fun (x, y) ->
      Crypto_params.Runners.Tick.make_checked (fun () -> Checked.hash [|x; y|])
      )
    (fun (x, y) -> hash [|x; y|])
    (x, y)
