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

  let rounds_full = 8

  let rounds_partial = 33
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

  let salt (s : string) =
    let prefix_to_field (s : string) =
      Fq.of_bits Fold_lib.Fold.(to_list (string_bits (s :> string)))
      |> Option.value_exn
    in
    Poseidon.update params ~state:Poseidon.initial_state [|prefix_to_field s|]

  let bg_salt = lazy (salt (Hash_prefixes.bowe_gabizon_hash :> string))

  let hash ?message ~(a : G1.t) ~(b : G2.t) ~(c : G1.t) ~(delta_prime : G2.t) :
      G1.t =
    Poseidon.hash ~init:(Lazy.force bg_salt) params
      (Array.concat
         [g1 a; g2 b; g1 c; g2 delta_prime; Option.value ~default:[||] message])
    |> group_map |> G1.of_affine
end

module Demo = Mnt6753.Make_bowe_gabizon (Hash)
include Demo

let instance_hash_salt =
  lazy (Hash.salt (Hash_prefixes.transition_system_snark :> string))

let vk_to_field_elements {Verification_key.query; delta; alpha_beta} =
  let g1 t =
    let x, y = G1.to_affine_exn t in
    [|x; y|]
  in
  let fqk (x, y) = List.concat_map ~f:Fq3.to_list [x; y] |> Array.of_list in
  let g2 (t : G2.t) = fqk (G2.to_affine_exn t) in
  Array.concat
    (List.map ~f:g1 (Array.to_list query) @ [g2 delta; fqk alpha_beta])

let instance_hash (wrap_vk : Verification_key.t) =
  let init =
    Poseidon.update Hash.params
      ~state:(Lazy.force instance_hash_salt)
      (vk_to_field_elements wrap_vk)
  in
  stage (fun state_hash -> Poseidon.hash Hash.params ~init [|state_hash|])

let split_last_exn =
  let rec go acc x xs =
    match xs with [] -> (List.rev acc, x) | x' :: xs -> go (x :: acc) x' xs
  in
  function [] -> failwith "split_last: Empty list" | x :: xs -> go [] x xs

let fq_to_scalars (x : Fq.t) =
  let xs, b = split_last_exn (Fq.to_bits x) in
  let zero = N.of_int 0 in
  let one = N.of_int 1 in
  [ List.foldi xs ~init:zero ~f:(fun i acc b ->
        if b then N.(log_or acc (shift_left one i)) else acc )
  ; (if b then one else zero) ]

let verify verification_key =
  let pvk = Verification_key.Processed.create verification_key in
  let instance_hash = unstage (instance_hash verification_key) in
  stage (fun state_hash proof ->
      verify pvk (fq_to_scalars (instance_hash state_hash)) proof )
