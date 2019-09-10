open Core_kernel

(*
   1 / 11
   =
38089537243562684911222013446582397389246099927230862792530457200932138920519187975508085239809399019470973610807689524839248234083267140972451128958905814696110378477590967674064016488951271336010850653690825603837076796509091
*)

module Chain = struct
  type move = Add of int * int | Sub of int * int [@@deriving sexp]

  type t = move list [@@deriving sexp]

  let choose_lte n = List.init (n + 1) ~f:Fn.id

  let all_chains max_size =
    let open List.Let_syntax in
    let rec go length =
      if length = max_size then return []
      else
        let%map i = choose_lte length
        and j = choose_lte length
        and op = [(fun i j -> Add (i, j)); (fun i j -> Sub (i, j))]
        and rest = go (length + 1) in
        op i j :: rest
    in
    go 0

  let evaluate_chain c =
    let n = List.length c in
    let arr = Array.init (n + 1) ~f:(fun _ -> 0) in
    arr.(0) <- 1 ;
    List.iteri c ~f:(fun k move ->
        arr.(k + 1)
        <- ( match move with
           | Add (i, j) ->
               arr.(i) + arr.(j)
           | Sub (i, j) ->
               arr.(i) - arr.(j) ) ) ;
    arr

  let value_exn x = Option.value_exn x

  let find_chain ?(max_size = 5) desired_value =
    List.filter (all_chains max_size) ~f:(fun chain ->
        Array.exists (evaluate_chain chain) ~f:(( = ) desired_value) )
    |> List.min_elt ~compare:(fun c1 c2 ->
           compare (List.length c1) (List.length c2) )
    |> value_exn
end

type params = {r: int}

module type Params_intf = sig
  module Impl : Snarky.Snark_intf.Run

  open Impl

  val to_the_alpha : Field.t -> Field.t
  val alphath_root : Field.t -> Field.t
end

module Make (Run : Snarky.Snark_intf.Run) = struct
  open Run

  module Block = struct
    type t = Field.t array

    let add = Array.map2_exn ~f:Field.( + )
  end

  let split n arr =
    let a = Array.slice arr in
    (a 0 n, a n (Array.length arr))

  (* A good choice of parameters:
   alpha = 11
   r = 2
   c = 1
   num_rounds = 11 *)

  (*
  r=2, c=1, num_rounds=22
  r=10, c=1, num_rounds=10
*)

  let add_block ~state block =
    Array.iteri block ~f:(fun i bi -> state.(i) <- Field.( + ) state.(i) bi)

  let sponge perm inputs state ~output_length =
    let state =
      Array.fold ~init:state inputs ~f:(fun state block ->
          add_block ~state block ; perm state )
    in
    Array.slice state 0 output_length

  let alpha = 11

  (* With alpha = 11 can get away with just 11 rounds. *)

  (* sage: (2*753) * (1 + 1.6666) / (10 * 3 * (2 * 5)) 
 *)
  let security _num_rounds = ()

  let to_the_alpha x =
    let open Field in
    let zero = square in
    let one a = square a * x in
    let one' = x in
    one' |> zero |> one |> one

  let alphath_root x =
    let open Field in
    let y = exists typ in
    let y10 = y |> square |> square |> ( * ) y |> square in
    assert_r1cs y10 y x ; y

  let sbox1 = to_the_alpha

  let sbox0 = alphath_root

  let round_constants ~m =
    let max_rounds = 100 in
    let x = Field.constant (Field.Constant.random ()) in
    let arr = Array.init m ~f:(fun _ -> x) in
    Array.init max_rounds ~f:(fun _ -> arr)

  let for_ n ~init ~f =
    let rec go i acc = if Int.(i = n) then acc else go (i + 1) (f i acc) in
    go 0 init

  let apply matrix v =
    let dotv row =
      Array.reduce_exn (Array.map2_exn v row ~f:Field.scale) ~f:Field.( + )
    in
    Array.map matrix ~f:dotv

  let block_cipher state ~rounds ~round_constants ~mds =
    add_block ~state round_constants.(0) ;
    for_ (2 * rounds) ~init:state ~f:(fun r state ->
        let sbox = if Int.(r mod 2 = 0) then sbox0 else sbox1 in
        Array.map_inplace state ~f:sbox ;
        let state = apply mds state in
        add_block ~state round_constants.(r + 1) ;
        state )

  let mds ~m =
    let x = Field.Constant.random () in
    let arr = Array.init m ~f:(fun _ -> x) in
    Array.init m ~f:(fun _ -> arr)

  let hash inputs =
    let rounds = 11 in
    let m = 3 in
    let round_constants = round_constants ~m in
    let perm = block_cipher ~rounds ~round_constants ~mds:(mds ~m) in
    sponge perm inputs (Array.init m ~f:(fun _ -> Field.zero)) ~output_length:1

  let () =
    Run.constraint_count (fun () ->
        let x = exists Field.typ in
        let y = exists Field.typ in
        hash [|[|x; y|]|] )
    |> printf "%d\n%!"
end
