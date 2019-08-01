open Core_kernel
open Snarkette
open Default_backend.Backend

let flip lst =
  let n = List.length (List.hd_exn lst) in
  List.map
    ~f:(fun i -> List.map ~f:(fun x -> List.nth_exn x i) lst)
    (List.range 0 n)

let rec list_first l n =
  if n = 0 then []
  else match l with [] -> [] | hd :: tl -> hd :: list_first tl (n - 1)

let rec list_except_first l n =
  if n = 0 then l
  else match l with [] -> [] | _ :: tl -> list_except_first tl (n - 1)

let list_replace lst idx new_val =
  list_first lst idx @ [new_val] @ list_except_first lst (idx + 1)

let reverse = List.fold_left ~init:[] ~f:(fun lst x -> x :: lst)

let rec replicate num fn =
  if num = 0 then [] else fn () :: replicate (num - 1) fn

let shift poly diff =
  let deg = Fr_laurent.deg poly in
  let coeffs = Fr_laurent.coeffs poly in
  Fr_laurent.create (deg + diff) coeffs

let shift_y poly diff =
  let deg = Bivariate_fr_laurent.deg poly in
  let coeffs = Bivariate_fr_laurent.coeffs poly in
  let rec helper lst =
    match lst with [] -> [] | hd :: tl -> shift hd diff :: helper tl
  in
  Bivariate_fr_laurent.create deg (helper coeffs)

let eval_on_y y l =
  let deg = Bivariate_fr_laurent.deg l in
  let coeffs = Bivariate_fr_laurent.coeffs l in
  Fr_laurent.create deg (List.map ~f:(fun ll -> Fr_laurent.eval ll y) coeffs)

let eval_on_x x l =
  let deg = Bivariate_fr_laurent.deg l in
  let coeffs = Bivariate_fr_laurent.coeffs l in
  let f ex lau =
    if ex >= 0 then
      Fr_laurent.( * ) lau (Fr_laurent.create 0 [Fr.( ** ) x (Nat.of_int ex)])
    else
      Fr_laurent.( * ) lau
        (Fr_laurent.create 0 [Fr.( / ) Fr.one (Fr.( ** ) x (Nat.of_int (-ex)))])
  in
  let rec ff d coeffs =
    match coeffs with
    | [] ->
        Fr_laurent.zero
    | hd :: tl ->
        Fr_laurent.( + ) (f d hd) (ff (d + 1) tl)
  in
  ff deg coeffs

let eval_on_x_y x y l = Fr_laurent.eval (eval_on_y y l) x

(* each constant coefficient in the univariate poly L becomes an equivalent
   constant poly in Y (as the coefficient of the same X term) *)
let convert_to_two_variate_X l =
  let deg = Fr_laurent.deg l in
  let coeffs = Fr_laurent.coeffs l in
  Bivariate_fr_laurent.create deg
    (List.map ~f:(fun e -> Fr_laurent.create 0 [e]) coeffs)

(* the univariate polynomial L becomes the Y poly that is the constant term of the X poly *)
let convert_to_two_variate_Y l = Bivariate_fr_laurent.create 0 [l]

let hadamardp = List.map2_exn ~f:Fr.( * )
