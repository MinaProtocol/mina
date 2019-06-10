open Core
open Snarkette.Mnt6_80
open Laurent
module FqLaurent = Make_field_laurent (N) (Fq)

let makeLaurentForTest deg ints =
  FqLaurent.create deg (List.map ints ~f:Fq.of_int)

let test polyA polyB polySum polyDifference polyProduct =
  assert (FqLaurent.equal polyA polyA) ;
  assert (FqLaurent.equal polyB polyB) ;
  assert (not (FqLaurent.equal polyA polyB)) ;
  assert (FqLaurent.equal (FqLaurent.( + ) polyA polyB) polySum) ;
  assert (FqLaurent.equal (FqLaurent.( - ) polyA polyB) polyDifference) ;
  assert (FqLaurent.equal (FqLaurent.( * ) polyA polyB) polyProduct) ;
  assert (
    FqLaurent.equal
      (FqLaurent.( - ) polyB polyA)
      (FqLaurent.negate polyDifference) ) ;
  assert (
    FqLaurent.equal (FqLaurent.( + ) (FqLaurent.( - ) polyA polyB) polyB) polyA
  ) ;
  assert (
    FqLaurent.equal (FqLaurent.( / ) (FqLaurent.( * ) polyA polyB) polyB) polyA
  ) ;
  assert (
    FqLaurent.equal (FqLaurent.( / ) (FqLaurent.( * ) polyA polyB) polyA) polyB
  )

let%test_unit "test1" =
  let polyA = makeLaurentForTest 0 [2; 0; 1] in
  (* 2 + x^2 *)
  let polyB = makeLaurentForTest 1 [1; 3] in
  (* x + 3x^2 *)
  let polySum = makeLaurentForTest 0 [2; 1; 4] in
  (* 2 + x + 4x^2 *)
  let polyDifference = makeLaurentForTest 0 [2; -1; -2] in
  (* 2 - x - 2x^2 *)
  let polyProduct = makeLaurentForTest 1 [2; 6; 1; 3] in
  (* 2x + 6x^2 + x^3 + 3x^4 *)
  test polyA polyB polySum polyDifference polyProduct

let%test_unit "test2" =
  let polyA = makeLaurentForTest (-3) [-1; 0; 0; 4; 0; -2] in
  (* -x^{-3} + 4 - 2x^2 *)
  let polyB = makeLaurentForTest (-1) [2; 0; 1; 4] in
  (* 2x^{-1} + x + 4x^2 *)
  let polySum = makeLaurentForTest (-3) [-1; 0; 2; 4; 1; 2] in
  (* -x^{-3} + 2x^{-1} + 4 + x + 2x^2 *)
  let polyDifference = makeLaurentForTest (-3) [-1; 0; -2; 4; -1; -6] in
  (* -x^{-3} -2x^{-1} + 4 - x - 6x^2 *)
  let polyProduct = makeLaurentForTest (-4) [-2; 0; -1; 4; 0; 0; 16; -2; -8] in
  (* -2x^{-4} - x^{-2} + 4x^{-1} + 16x^2 - 2x^3 - 8x^4 *)
  test polyA polyB polySum polyDifference polyProduct

let%test_unit "evaluationTest" =
  let polyA = makeLaurentForTest 0 [2; 0; 1] in
  assert (Fq.equal (FqLaurent.eval polyA Fq.one) (Fq.of_string "3")) ;
  assert (
    Fq.equal (FqLaurent.eval polyA (Fq.of_string "3")) (Fq.of_string "11") ) ;
  assert (
    Fq.equal (FqLaurent.eval polyA (Fq.of_string "-3")) (Fq.of_string "11") )
