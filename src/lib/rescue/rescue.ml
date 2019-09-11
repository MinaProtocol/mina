open Core_kernel

let rounds = 11

module Params = struct
  type 'a t = {mds: 'a array array; round_constants: 'a array array}
  [@@deriving bin_io]

  let map {mds; round_constants} ~f =
    let f = Array.map ~f:(Array.map ~f) in
    {mds= f mds; round_constants= f round_constants}
end

module Make (Inputs : Inputs.S) = struct
  open Inputs

  let add_block ~state block =
    Array.iteri block ~f:(fun i bi -> state.(i) <- Field.( + ) state.(i) bi)

  let sponge perm blocks state =
    Array.fold ~init:state blocks ~f:(fun state block ->
        add_block ~state block ; perm state )

  let sbox0, sbox1 = (alphath_root, to_the_alpha)

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

  let to_blocks r a =
    let n = Array.length a in
    Array.init
      ((n + r - 1) / r)
      ~f:(fun i ->
        Array.init r ~f:(fun j ->
            let k = (r * i) + j in
            if k < n then a.(k) else Field.zero ) )

  let%test_unit "block" =
    let z = Field.zero in
    [%test_eq: unit array array]
      (Array.map (to_blocks 2 [|z; z; z|]) ~f:(Array.map ~f:ignore))
      [|[|(); ()|]; [|(); ()|]|]

  let hash {Params.mds; round_constants} inputs =
    let m = Array.length mds in
    let r = m - 1 in
    let perm = block_cipher ~rounds ~round_constants ~mds in
    let final_state =
      sponge perm (to_blocks r inputs) (Array.init m ~f:(fun _ -> Field.zero))
    in
    final_state.(0)
end
