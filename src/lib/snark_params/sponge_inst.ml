open Core

let params : _ Sponge.Params.t =
  let open Crypto_params.Rescue_params in
  {mds; round_constants}

module Inputs = struct
  module Field = Crypto_params.Tick0.Field

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

  let alphath_root =
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
    let root = alphath_root x in
    [%test_eq: Field.t] (to_the_alpha root) x
end

include Sponge.Make (Sponge.Rescue (Inputs))
module State = Sponge.State

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

    let alphath_root x =
      let open Field in
      let y =
        exists typ ~compute:(fun () ->
            Inputs.alphath_root (As_prover.read typ x) )
      in
      let y10 = y |> square |> square |> ( * ) y |> square in
      assert_r1cs y10 y x ; y

    let apply_matrix = None

    module Operations = Sponge.Make_operations (Field)
  end

  include Sponge.Make (Sponge.Rescue (Inputs))

  let hash = hash (Sponge.Params.map ~f:Field.constant params)
end

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

let%test_unit "rescue" =
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

module Poseidon = Sponge.Make (Sponge.Poseidon (Inputs))
