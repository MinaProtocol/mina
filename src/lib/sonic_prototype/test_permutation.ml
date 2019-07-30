open Core
open Default_backend.Backend
open Hashtbl
open Permutation
module Srs = Srs.Make (Default_backend.Backend)

let shuffle lst =
  List.sort lst ~compare:(fun a b -> hash (a, 123) - hash (b, 123))

let%test_unit "permutation" =
  let n = 20 in
  let sigma = shuffle (List.range 1 (n + 1)) in
  let psi = List.map (List.range 1 (n + 1)) ~f:(fun _ -> Fr.random ()) in
  let psi_poly = psi_poly_from_sigma_psi sigma psi in
  let x = Fr.random () in
  let alpha = Fr.random () in
  let d = 45 in
  let srs = Srs.create d x alpha in
  let y = Fr.random () in
  let z = Fr.random () in
  let proof = perm_p srs y z psi_poly in
  let bad_proof = {proof with perm_psi_eval= Fr.random ()} in
  assert (perm_v srs y z psi_poly proof) ;
  assert (not (perm_v srs y z psi_poly bad_proof))
