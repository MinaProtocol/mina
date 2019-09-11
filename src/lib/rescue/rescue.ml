open Core_kernel

(*
   1 / 11
   =
38089537243562684911222013446582397389246099927230862792530457200932138920519187975508085239809399019470973610807689524839248234083267140972451128958905814696110378477590967674064016488951271336010850653690825603837076796509091

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
*)

let rounds = 11

module Params = struct
  type 'a t = {mds: 'a array array; round_constants: 'a array array}
  [@@deriving bin_io]

  let map {mds; round_constants} ~f =
    let f = Array.map ~f:(Array.map ~f) in
    {mds= f mds; round_constants= f round_constants}

  let create ~m ~random_elt =
    let arr rows cols =
      Array.init rows ~f:(fun _ -> Array.init cols ~f:(fun _ -> random_elt ()))
    in
    {mds= arr m m; round_constants= arr ((2 * rounds) + 1) m}
end

(*

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
*)

module Make (Inputs : Inputs.S) = struct
  open Inputs

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

  let sponge perm inputs state =
    Array.fold ~init:state inputs ~f:(fun state block ->
        add_block ~state block ; perm state )

  (* With alpha = 11 can get away with just 11 rounds. *)

  (* sage: (2*753) * (1 + 1.6666) / (10 * 3 * (2 * 5)) 
 *)

  let sbox1 = to_the_alpha

  let sbox0 = alphath_root

  let for_ n ~init ~f =
    let rec go i acc = if Int.(i = n) then acc else go (i + 1) (f i acc) in
    go 0 init

  let apply matrix v =
    let dotv row =
      Array.reduce_exn (Array.map2_exn v row ~f:Field.( * )) ~f:Field.( + )
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

  let hash {Params.mds; round_constants} inputs =
    let m = Array.length mds in
    let perm = block_cipher ~rounds ~round_constants ~mds in
    let final_state =
      sponge perm inputs (Array.init m ~f:(fun _ -> Field.zero))
    in
    final_state.(0)
end
