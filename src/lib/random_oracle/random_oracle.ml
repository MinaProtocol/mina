[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Curve_choice
module Field = Tick0.Field

[%%else]

open Snark_params_nonconsensus
module Sponge_params = Sponge_params_nonconsensus.Sponge_params

[%%endif]

module State = struct
  include Array

  let map2 = map2_exn
end

module Input = Random_oracle_input

let params : _ Sponge.Params.t =
  let open Sponge_params in
  {mds; round_constants}

module Inputs = struct
  module Field = Field

  let rounds_full = 8

  let rounds_partial = 33

  [%%ifdef
  consensus_mechanism]

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

  [%%else]

  let to_the_alpha x =
    let open Field in
    let res = x in
    let res = res * res in
    (* x^2 *)
    let res = res * res in
    (* x^4 *)
    let res = res * x in
    (* x^5 *)
    let res = res * res in
    (* x^10 *)
    res * x

  [%%endif]

  module Operations = struct
    [%%ifdef
    consensus_mechanism]

    let add_assign ~state i x = Field.(state.(i) += x)

    let apply_affine_map (rows, c) v =
      Array.mapi rows ~f:(fun j row ->
          let open Field in
          let res = zero + zero in
          Array.iteri row ~f:(fun i r -> res += (r * v.(i))) ;
          res += c.(j) ;
          res )

    (* TODO: Have an explicit function for making a copy of a field element. *)
    let copy a = Array.map a ~f:(fun x -> Field.(x + zero))

    [%%else]

    let add_assign ~state i x = Field.(state.(i) <- state.(i) + x)

    let apply_affine_map (rows, c) v =
      Array.mapi rows ~f:(fun j row ->
          let res = ref Field.zero in
          Array.iteri row ~f:(fun i r -> res := Field.(!res + (r * v.(i)))) ;
          (res := Field.(!res + c.(j))) ;
          !res )

    let copy a = Array.map a ~f:Fn.id

    [%%endif]
  end

  let _alphath_root =
    let inv_alpha =
      Bigint.of_string Sponge_params.inv_alpha |> Bigint.to_zarith_bigint
    in
    let k = 4 in
    let chunks = (Field.size_in_bits + (k - 1)) / k in
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
  open Field

  type nonrec t = t

  let to_bits ?length x =
    match length with
    | None ->
        unpack x
    | Some length ->
        List.take (unpack x) length
end

include Sponge.Make_hash (Sponge.Poseidon (Inputs))

let update ~state = update ~state params

let hash ?init = hash ?init params

[%%ifdef
consensus_mechanism]

module Checked = struct
  module Inputs = struct
    module Field = struct
      open Tick0

      (* The linear combinations involved in computing Poseidon do not involve very many
   variables, but if they are represented as arithmetic expressions (that is, "Cvars"
   which is what Field.t is under the hood) the expressions grow exponentially in
   in the number of rounds. Thus, we compute with Field elements represented by
   a "reduced" linear combination. That is, a coefficient for each variable and an
   constant term.
*)
      type t = Field.t Int.Map.t * Field.t

      let to_cvar ((m, c) : t) : Field.Var.t =
        Map.fold m ~init:(Field.Var.constant c) ~f:(fun ~key ~data acc ->
            let x =
              let v = Snarky.Cvar.Var key in
              if Field.equal data Field.one then v else Scale (data, v)
            in
            match acc with
            | Constant c when Field.equal Field.zero c ->
                x
            | _ ->
                Add (x, acc) )

      let constant c = (Int.Map.empty, c)

      let of_cvar (x : Field.Var.t) =
        match x with
        | Constant c ->
            constant c
        | Var v ->
            (Int.Map.singleton v Field.one, Field.zero)
        | x ->
            let c, ts = Field.Var.to_constant_and_terms x in
            ( Int.Map.of_alist_reduce
                (List.map ts ~f:(fun (f, v) -> (Tick_backend.Var.index v, f)))
                ~f:Field.add
            , Option.value ~default:Field.zero c )

      let ( + ) (t1, c1) (t2, c2) =
        ( Map.merge t1 t2 ~f:(fun ~key:_ t ->
              match t with
              | `Left x ->
                  Some x
              | `Right y ->
                  Some y
              | `Both (x, y) ->
                  Some Field.(x + y) )
        , Field.add c1 c2 )

      let ( * ) (t1, c1) (t2, c2) =
        assert (Int.Map.is_empty t1) ;
        (Map.map t2 ~f:(Field.mul c1), Field.mul c1 c2)

      let zero = constant Field.zero
    end

    let rounds_full = 8

    let rounds_partial = 33

    let to_the_alpha x =
      let open Runners.Tick.Field in
      let zero = square in
      let one a = square a * x in
      let one' = x in
      one' |> zero |> one |> one

    let to_the_alpha x = Field.of_cvar (to_the_alpha (Field.to_cvar x))

    module Operations = Sponge.Make_operations (Field)
  end

  module Digest = struct
    open Runners.Tick.Field

    type nonrec t = t

    let to_bits ?(length = Field.size_in_bits) x =
      List.take (choose_preimage_var ~length:Field.size_in_bits x) length
  end

  include Sponge.Make_hash (Sponge.Poseidon (Inputs))

  let params = Sponge.Params.map ~f:Inputs.Field.constant params

  open Inputs.Field

  let update ~state xs =
    let f = Array.map ~f:of_cvar in
    update params ~state:(f state) (f xs) |> Array.map ~f:to_cvar

  let hash ?init xs =
    O1trace.measure "Random_oracle.hash" (fun () ->
        hash
          ?init:(Option.map init ~f:(State.map ~f:constant))
          params (Array.map xs ~f:of_cvar)
        |> to_cvar )

  let pack_input =
    Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.Var.pack

  let initial_state = Array.map initial_state ~f:to_cvar

  let digest xs = xs.(0)
end

[%%endif]

let pack_input =
  Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.project

let prefix_to_field (s : string) =
  let bits_per_character = 8 in
  assert (bits_per_character * String.length s < Field.size_in_bits) ;
  Field.project Fold_lib.Fold.(to_list (string_bits (s :> string)))

let salt (s : string) = update ~state:initial_state [|prefix_to_field s|]

let%test_unit "iterativeness" =
  let x1 = Field.random () in
  let x2 = Field.random () in
  let x3 = Field.random () in
  let x4 = Field.random () in
  let s_full = update ~state:initial_state [|x1; x2; x3; x4|] in
  let s_it =
    update ~state:(update ~state:initial_state [|x1; x2|]) [|x3; x4|]
  in
  [%test_eq: Field.t array] s_full s_it

[%%ifdef
consensus_mechanism]

let%test_unit "sponge checked-unchecked" =
  let module T = Tick0 in
  let x = T.Field.random () in
  let y = T.Field.random () in
  T.Test.test_equal ~equal:T.Field.equal ~sexp_of_t:T.Field.sexp_of_t
    T.Typ.(field * field)
    T.Typ.field
    (fun (x, y) -> Runners.Tick.make_checked (fun () -> Checked.hash [|x; y|]))
    (fun (x, y) -> hash [|x; y|])
    (x, y)

[%%endif]
