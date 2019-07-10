open Core
open Snarkette.Mnt6_80
open Laurent
module Fq_laurent = Make_laurent (N) (Fq)

let make_laurent_for_test deg ints =
  Fq_laurent.create deg (List.map ints ~f:Fq.of_int)

let test poly_a poly_b poly_sum poly_difference poly_product =
  Fq_laurent.equal poly_a poly_a
  && Fq_laurent.equal poly_b poly_b
  && (not (Fq_laurent.equal poly_a poly_b))
  && Fq_laurent.equal (Fq_laurent.( + ) poly_a poly_b) poly_sum
  && Fq_laurent.equal (Fq_laurent.( - ) poly_a poly_b) poly_difference
  && Fq_laurent.equal (Fq_laurent.( * ) poly_a poly_b) poly_product
  && Fq_laurent.equal
       (Fq_laurent.( - ) poly_b poly_a)
       (Fq_laurent.negate poly_difference)
  && Fq_laurent.equal
       (Fq_laurent.( + ) (Fq_laurent.( - ) poly_a poly_b) poly_b)
       poly_a
  && Fq_laurent.equal
       (Fq_laurent.( / ) (Fq_laurent.( * ) poly_a poly_b) poly_b)
       poly_a
  && Fq_laurent.equal
       (Fq_laurent.( / ) (Fq_laurent.( * ) poly_a poly_b) poly_a)
       poly_b

let generic_test poly_a poly_b =
  Fq_laurent.equal
    (Fq_laurent.( + ) (Fq_laurent.( - ) poly_a poly_b) poly_b)
    poly_a
  && Fq_laurent.equal
       (Fq_laurent.( + ) (Fq_laurent.( - ) poly_b poly_a) poly_a)
       poly_b
  && Fq_laurent.equal
       (Fq_laurent.( / ) (Fq_laurent.( * ) poly_a poly_b) poly_b)
       poly_a
  && Fq_laurent.equal
       (Fq_laurent.( / ) (Fq_laurent.( * ) poly_a poly_b) poly_a)
       poly_b

let%test_unit "test1" =
  let poly_a = make_laurent_for_test 0 [2; 0; 1] in
  (* 2 + x^2 *)
  let poly_b = make_laurent_for_test 1 [1; 3] in
  (* x + 3x^2 *)
  let poly_sum = make_laurent_for_test 0 [2; 1; 4] in
  (* 2 + x + 4x^2 *)
  let poly_difference = make_laurent_for_test 0 [2; -1; -2] in
  (* 2 - x - 2x^2 *)
  let poly_product = make_laurent_for_test 1 [2; 6; 1; 3] in
  (* 2x + 6x^2 + x^3 + 3x^4 *)
  assert (test poly_a poly_b poly_sum poly_difference poly_product)

let%test_unit "test2" =
  let poly_a = make_laurent_for_test (-3) [-1; 0; 0; 4; 0; -2] in
  (* -x^{-3} + 4 - 2x^2 *)
  let poly_b = make_laurent_for_test (-1) [2; 0; 1; 4] in
  (* 2x^{-1} + x + 4x^2 *)
  let poly_sum = make_laurent_for_test (-3) [-1; 0; 2; 4; 1; 2] in
  (* -x^{-3} + 2x^{-1} + 4 + x + 2x^2 *)
  let poly_difference = make_laurent_for_test (-3) [-1; 0; -2; 4; -1; -6] in
  (* -x^{-3} -2x^{-1} + 4 - x - 6x^2 *)
  let poly_product =
    make_laurent_for_test (-4) [-2; 0; -1; 4; 0; 0; 16; -2; -8]
  in
  (* -2x^{-4} - x^{-2} + 4x^{-1} + 16x^2 - 2x^3 - 8x^4 *)
  assert (test poly_a poly_b poly_sum poly_difference poly_product)

let%test_unit "evaluation test" =
  let poly_a = make_laurent_for_test 0 [2; 0; 1] in
  assert (Fq.equal (Fq_laurent.eval poly_a Fq.one) (Fq.of_int 3)) ;
  assert (Fq.equal (Fq_laurent.eval poly_a (Fq.of_int 3)) (Fq.of_int 11)) ;
  assert (Fq.equal (Fq_laurent.eval poly_a (Fq.of_int (-3))) (Fq.of_int 11))

let generic_laurent_test =
  QCheck.Test.make ~count:10 ~name:"generic laurent test"
    QCheck.(
      pair int (quad small_nat small_nat (small_list int) (small_list int)))
    (fun (l, (a_deg, b_deg, a_nums, b_nums)) ->
      Random.init l ;
      let poly_a = make_laurent_for_test a_deg a_nums in
      let poly_b = make_laurent_for_test b_deg b_nums in
      QCheck.assume (not Fq_laurent.(equal poly_a zero)) ;
      QCheck.assume (not Fq_laurent.(equal poly_b zero)) ;
      generic_test poly_a poly_b)

let () = QCheck.Test.check_exn generic_laurent_test
