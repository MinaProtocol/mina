open Core_kernel
open Snarkette
open Snarkette.Mnt6_80
open Laurent
module Fq_target = Fq6
module Fr = Snarkette.Mnt4_80.Fq
module Fr_laurent = Make_laurent (N) (Fr)
module Bivariate_Fr_laurent = Make_laurent (N) (Fr_laurent)

let eval_on_Y y l =
  let deg = Bivariate_Fr_laurent.deg l in
  let coeffs = Bivariate_Fr_laurent.coeffs l in
  Fr_laurent.create deg (List.map ~f:(fun ll -> Fr_laurent.eval ll y) coeffs)

let eval_on_X x l =
  let deg = Bivariate_Fr_laurent.deg l in
  let coeffs = Bivariate_Fr_laurent.coeffs l in
  let f ex lau =
    if ex >= 0 then
      Fr_laurent.( * ) lau (Fr_laurent.create 0 [Fr.( ** ) x (Nat.of_int ex)])
    else
      Fr_laurent.( * ) lau
        (Fr_laurent.create 0 [Fr.( / ) Fr.one (Fr.( ** ) x (Nat.of_int (-ex)))])
  in
  let rec ff d coeffs =
    match coeffs with [] -> [] | hd :: tl -> f d hd :: ff (d + 1) tl
  in
  ff deg coeffs

(* each constant coefficient in the univariate poly L becomes an equivalent
   constant poly in Y (as the coefficient of the same X term) *)
let convert_to_two_variate_X l =
  let deg = Fr_laurent.deg l in
  let coeffs = Fr_laurent.coeffs l in
  Bivariate_Fr_laurent.create deg
    (List.map ~f:(fun e -> Fr_laurent.create 0 [e]) coeffs)

(* the univariate polynomial L becomes the Y poly that is the constant term of the X poly *)
let convert_to_two_variate_Y l = Bivariate_Fr_laurent.create 0 [l]

let hadamardp = List.map2_exn ~f:Fr.( * )
