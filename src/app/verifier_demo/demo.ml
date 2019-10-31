open Core_kernel
open Snarkette
open Mnt6753

module Inputs = struct
  module Field = Fq

  let to_the_alpha x =
    let open Fq in
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

  module Operations = Sponge.Make_operations (Fq)
end

module Poseidon = Sponge.Make (Sponge.Poseidon (Inputs))

module Hash = struct
  open Mnt6753

  let params : _ Sponge.Params.t =
    let open Sponge_params in
    {mds; round_constants}

  let g1 (g : G1.t) : Fq.t array =
    let x, y = G1.to_affine_exn g in
    [|x; y|]

  let g2 (g : G2.t) : Fq.t array =
    let x, y = G2.to_affine_exn g in
    Array.of_list (List.concat_map ~f:Fq3.to_list [x; y])

  let bg_params =
    Group_map.Params.create
      (module Fq)
      ~a:G1.Coefficients.a ~b:G1.Coefficients.b

  let group_map = Group_map.to_group (module Fq) ~params:bg_params

  let hash ?message ~(a : G1.t) ~(b : G2.t) ~(c : G1.t) ~(delta_prime : G2.t) :
      G1.t =
    Poseidon.hash params
      (Array.concat
         [g1 a; g2 b; g1 c; g2 delta_prime; Option.value ~default:[||] message])
    |> group_map |> G1.of_affine
end

module Demo = Mnt6753.Make_bowe_gabizon (Hash)
include Demo
