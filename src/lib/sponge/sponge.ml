open Core_kernel
module Params = Params
module State = Array

let for_ n ~init ~f =
  let rec go i acc = if Int.(i = n) then acc else go (i + 1) (f i acc) in
  go 0 init

module Make_operations (Field : Intf.Field) = struct
  let add_block ~state block =
    Array.iteri block ~f:(fun i bi -> state.(i) <- Field.( + ) state.(i) bi)

  let apply_matrix matrix v =
    let dotv row =
      Array.reduce_exn (Array.map2_exn row v ~f:Field.( * )) ~f:Field.( + )
    in
    Array.map matrix ~f:dotv

  let copy = Array.copy
end

let m = 3

module Rescue (Inputs : Intf.Inputs.Rescue) = struct
  (*
   We refer below to this paper: https://eprint.iacr.org/2019/426.pdf.

I arrived at this value for the number of rounds in the following way.
As mentioned on page 34, the cost of performing the Grobner basis attack is estimated as

( (n + d) choose d ) ^ omega
where 

- omega is some number which is known to be >= 2
- n = 1 + m*N is the number of variables in the system of equations on page 3
- d is a quantity which they estimate as ((alpha - 1)(m*N + 1) + 1) / 2
- m is the state size, which we can choose
- N is the number of rounds which we can choose

In our case, `alpha = 11`, and I took `m = 3` which is optimal for binary Merkle trees.
Evaluating the above formula with these values and `N = 11` and `omega = 2` yields an attack complexity
of a little over 2^257, which if we take the same factor of 2 security margin as they use in the paper,
gives us a security level of 257/2 ~= 128.

NB: As you can see from the analysis this is really specialized to alpha = 11 and the number of rounds
should be higher for smaller alpha.
*)

  let rounds = 11

  open Inputs
  include Operations
  module Field = Field

  let sbox0, sbox1 = (alphath_root, to_the_alpha)

  let block_cipher {Params.round_constants; mds} state =
    add_block ~state round_constants.(0) ;
    for_ (2 * rounds) ~init:state ~f:(fun r state ->
        let sbox = if Int.(r mod 2 = 0) then sbox0 else sbox1 in
        Array.map_inplace state ~f:sbox ;
        let state = apply_matrix mds state in
        add_block ~state round_constants.(r + 1) ;
        state )
end

module Poseidon (Inputs : Intf.Inputs.Common) = struct
  open Inputs
  include Operations
  module Field = Field

  let rounds_full = 8

  let rounds_partial = 33

  let half_rounds_full = rounds_full / 2

  let%test "rounds_full" = half_rounds_full * 2 = rounds_full

  let for_ n init ~f = for_ n ~init ~f

  let block_cipher {Params.round_constants; mds} state =
    let sbox = to_the_alpha in
    let full_half start =
      for_ half_rounds_full ~f:(fun r state ->
          add_block ~state round_constants.(start + r) ;
          Array.map_inplace state ~f:sbox ;
          apply_matrix mds state )
    in
    full_half 0 state
    |> for_ rounds_partial ~f:(fun r state ->
           add_block ~state round_constants.(half_rounds_full + r) ;
           state.(0) <- sbox state.(0) ;
           apply_matrix mds state )
    |> full_half (half_rounds_full + rounds_partial)
end

module Make (P : Intf.Permutation) = struct
  open P

  let sponge perm blocks ~state =
    Array.fold ~init:state blocks ~f:(fun state block ->
        add_block ~state block ; perm state )

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

  let r = m - 1

  let update params ~state inputs =
    let state = copy state in
    sponge (block_cipher params) (to_blocks r inputs) ~state

  let digest state = state.(0)

  let initial_state = Array.init m ~f:(fun _ -> Field.zero)

  let hash ?(init = initial_state) params inputs =
    update params ~state:init inputs |> digest
end
