open Core

open Snarkette.Mnt6_80
open Laurent

let makeLaurentForTest idx ints =
  let rec convert ints =
    match ints with
    | [] -> []
    | hd::tl -> (if hd < 0 then Fq.negate (Fq.of_int (abs hd)) else Fq.of_int hd) :: convert tl
  in
  makeLaurent idx (convert ints)

let test polyA polyB polySum polyDifference polyProduct =
  assert (eqLaurent (addLaurent polyA polyB) polySum);
  assert (eqLaurent (mulLaurent polyA polyB) polyProduct);
  assert (eqLaurent (subtractLaurent polyA polyB) polyDifference);
  assert (eqLaurent (subtractLaurent polyB polyA) (negateLaurent polyDifference));
  assert (eqLaurent (addLaurent (subtractLaurent polyA polyB) polyB) polyA);
  assert (eqLaurent (quotLaurent (mulLaurent polyA polyB) polyB) polyA);
  assert (eqLaurent (quotLaurent (mulLaurent polyA polyB) polyA) polyB)

let%test_unit "test1" =
  let polyA = makeLaurentForTest 0 [2; 0; 1] in (* 2 + x^2 *)
  let polyB = makeLaurentForTest 1 [1; 3] in (* x + 3x^2 *)
  let polySum = makeLaurentForTest 0 [2; 1; 4] in (* 2 + x + 4x^2 *)
  let polyDifference = makeLaurentForTest 0 [2; -1; -2] in (* 2 - x - 2x^2 *)
  let polyProduct = makeLaurentForTest 1 [2; 6; 1; 3] in (* 2x + 6x^2 + x^3 + 3x^4 *)
  test polyA polyB polySum polyDifference polyProduct

let%test_unit "test2" =
  let polyA = makeLaurentForTest (-3) [-1; 0; 0; 4; 0; -2] in (* -x^{-3} + 4 - 2x^2 *)
  let polyB = makeLaurentForTest (-1) [2; 0; 1; 4] in (* 2x^{-1} + x + 4x^2 *)
  let polySum = makeLaurentForTest (-3) [-1; 0; 2; 4; 1; 2] in (* -x^{-3} + 2x^{-1} + 4 + x + 2x^2 *)
  let polyDifference = makeLaurentForTest (-3) [-1; 0; -2; 4; -1; -6] in (* -x^{-3} -2x^{-1} + 4 - x - 6x^2 *)
  let polyProduct = makeLaurentForTest (-4) [-2; 0; -1; 4; 0; 0; 16; -2; -8] in (* -2x^{-4} - x^{-2} + 4x^{-1} + 16x^2 - 2x^3 - 8x^4 *)
  test polyA polyB polySum polyDifference polyProduct