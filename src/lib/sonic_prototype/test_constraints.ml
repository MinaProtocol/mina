open Core
open Arithmetic_circuit
open Constraints
open Default_backend.Backend

let (example_assignment : Assignment.t) =
  { a_l= [Fr.of_int 1; Fr.of_int 2]
  ; a_r= [Fr.of_int 3; Fr.of_int 4]
  ; a_o= [Fr.of_int 5; Fr.of_int 6] }

let (example_weights : Gate_weights.t) =
  { w_l=
      [ [Fr.of_int 1; Fr.of_int 2]
      ; [Fr.of_int 3; Fr.of_int 4] ]
  ; w_r=
      [ [Fr.of_int 5; Fr.of_int 6]
      ; [Fr.of_int 7; Fr.of_int 8] ]
  ; w_o=
      [ [Fr.of_int 9; Fr.of_int 10]
      ; [Fr.of_int 11; Fr.of_int 12] ] }

let r_poly_output =
  Bivariate_fr_laurent.create (-4)
    [ Fr_laurent.create (-4) [Fr.of_int 6]
    ; Fr_laurent.create (-3) [Fr.of_int 5]
    ; Fr_laurent.create (-2) [Fr.of_int 4]
    ; Fr_laurent.create (-1) [Fr.of_int 3]
    ; Fr_laurent.create 0 []
    ; Fr_laurent.create 1 [Fr.of_int 1]
    ; Fr_laurent.create 2 [Fr.of_int 2] ]

let s_poly_output =
  Bivariate_fr_laurent.create (-2)
    [ Fr_laurent.create 0
        [ Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 3
        ; Fr.of_int 4 ]
    ; Fr_laurent.create 0
        [ Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 1
        ; Fr.of_int 2 ]
    ; Fr_laurent.create 0 []
    ; Fr_laurent.create 0
        [ Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 5
        ; Fr.of_int 6 ]
    ; Fr_laurent.create 0
        [ Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 7
        ; Fr.of_int 8 ]
    ; Fr_laurent.create (-1)
        [ Fr.of_int (-1)
        ; Fr.of_int 0
        ; Fr.of_int (-1)
        ; Fr.of_int 0
        ; Fr.of_int 9
        ; Fr.of_int 10 ]
    ; Fr_laurent.create (-2)
        [ Fr.of_int (-1)
        ; Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int 0
        ; Fr.of_int (-1)
        ; Fr.of_int 11
        ; Fr.of_int 12 ] ]

let%test_unit "s_poly_test" =
  assert (Bivariate_fr_laurent.equal (s_poly example_weights) s_poly_output)

let%test_unit "r_poly_test" =
  assert (Bivariate_fr_laurent.equal (r_poly example_assignment) r_poly_output)

let satisfied () =
  let a_l = [Fr.random () ; Fr.random ()] in
  let a_r = [Fr.random () ; Fr.random ()] in
  let a_o = List.map2_exn a_l a_r ~f:(fun l r -> Fr.( * ) l r) in
  let w_l = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let w_r = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let w_o = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let q_max = 3 in
  let k_q q = (Fr.( + )
      (Fr.( + ) (List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a_l (List.map w_l ~f:(fun l -> List.nth_exn l q)) ~f:Fr.( * )))
      (List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a_r (List.map w_r ~f:(fun l -> List.nth_exn l q)) ~f:Fr.( * ))))
      (List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a_o (List.map w_o ~f:(fun l -> List.nth_exn l q)) ~f:Fr.( * ))))
    in
  let rec k_loop q =
    if q = q_max then [] else
    (k_q q) :: (k_loop (q + 1))
    in
  let k = k_loop 0 in
  let (assignment : Assignment.t) = { a_l; a_r; a_o } in
  let (weights : Gate_weights.t) = { w_l; w_r; w_o } in
  let n = List.length a_l in
  (assignment, weights, k, n)

let mult_not_satisfied () =
  let a_l = [Fr.random () ; Fr.random ()] in
  let a_r = [Fr.random () ; Fr.random ()] in
  let a_o = [Fr.random () ; Fr.random ()] in
  let w_l = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let w_r = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let w_o = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let q_max = 3 in
  let k_q q = (Fr.( + )
      (Fr.( + ) (List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a_l (List.map w_l ~f:(fun l -> List.nth_exn l q)) ~f:Fr.( * )))
      (List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a_r (List.map w_r ~f:(fun l -> List.nth_exn l q)) ~f:Fr.( * ))))
      (List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a_o (List.map w_o ~f:(fun l -> List.nth_exn l q)) ~f:Fr.( * ))))
    in
  let rec k_loop q =
    if q = q_max then [] else
    (k_q q) :: (k_loop (q + 1))
    in
  let k = k_loop 0 in
  let (assignment : Assignment.t) = { a_l; a_r; a_o } in
  let (weights : Gate_weights.t) = { w_l; w_r; w_o } in
  let n = List.length (List.hd_exn w_l) in
  (assignment, weights, k, n)

let add_not_satisfied () =
  let a_l = [Fr.random () ; Fr.random ()] in
  let a_r = [Fr.random () ; Fr.random ()] in
  let a_o = List.map2_exn a_l a_r ~f:(fun l r -> Fr.( * ) l r) in
  let w_l = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let w_r = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let w_o = [ [Fr.random () ; Fr.random () ; Fr.random ()]
            ; [Fr.random () ; Fr.random () ; Fr.random ()] ] in
  let k = [Fr.random () ; Fr.random () ; Fr.random ()] in
  let (assignment : Assignment.t) = { a_l; a_r; a_o } in
  let (weights : Gate_weights.t) = { w_l; w_r; w_o } in
  let n = List.length (List.hd_exn w_l) in
  (assignment, weights, k, n)

let satisfied_test =
  QCheck.Test.make ~count:10 ~name:"satisfied test"
  QCheck.(int)
  (fun l -> Random.init l ;
  let assignment, weights, k, n = satisfied () in
  let r = r_poly assignment in
  let s = s_poly weights in
  let k = k_poly k n in
  let t = t_poly r s k in
  let zero_coeff = List.nth_exn (Bivariate_fr_laurent.coeffs t) (0 - (Bivariate_fr_laurent.deg t)) in
  Fr_laurent.equal zero_coeff Fr_laurent.zero
  )

let mult_not_satisfied_test =
  QCheck.Test.make ~count:10 ~name:"mult not satisfied test"
  QCheck.(int)
  (fun l -> Random.init l ;
  let assignment, weights, k, n = mult_not_satisfied () in
  let r = r_poly assignment in
  let s = s_poly weights in
  let k = k_poly k n in
  let t = t_poly r s k in
  let zero_coeff = List.nth_exn (Bivariate_fr_laurent.coeffs t) (0 - (Bivariate_fr_laurent.deg t)) in
  not (Fr_laurent.equal zero_coeff Fr_laurent.zero)
  )

let add_not_satisfied_test =
  QCheck.Test.make ~count:10 ~name:"add not satisfied test"
  QCheck.(int)
  (fun l -> Random.init l ;
  let assignment, weights, k, n = add_not_satisfied () in
  let r = r_poly assignment in
  let s = s_poly weights in
  let k = k_poly k n in
  let t = t_poly r s k in
  let zero_coeff = List.nth_exn (Bivariate_fr_laurent.coeffs t) (0 - (Bivariate_fr_laurent.deg t)) in
  not (Fr_laurent.equal zero_coeff Fr_laurent.zero)
  )

let () =
  QCheck.Test.check_exn satisfied_test;
  QCheck.Test.check_exn mult_not_satisfied_test;
  QCheck.Test.check_exn add_not_satisfied_test
