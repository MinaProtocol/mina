open Arithmetic_circuit
open Constraints
open Default_backend.Backend

let (example_assignment : Assignment.t) =
  { a_l= [Fr.of_string "1"; Fr.of_string "2"]
  ; a_r= [Fr.of_string "3"; Fr.of_string "4"]
  ; a_o= [Fr.of_string "5"; Fr.of_string "6"] }

let (example_weights : Gate_weights.t) =
  { w_l=
      [ [Fr.of_string "1"; Fr.of_string "2"]
      ; [Fr.of_string "3"; Fr.of_string "4"] ]
  ; w_r=
      [ [Fr.of_string "5"; Fr.of_string "6"]
      ; [Fr.of_string "7"; Fr.of_string "8"] ]
  ; w_o=
      [ [Fr.of_string "9"; Fr.of_string "10"]
      ; [Fr.of_string "11"; Fr.of_string "12"] ] }

let r_poly_output =
  Bivariate_fr_laurent.create (-4)
    [ Fr_laurent.create (-4) [Fr.of_string "6"]
    ; Fr_laurent.create (-3) [Fr.of_string "5"]
    ; Fr_laurent.create (-2) [Fr.of_string "4"]
    ; Fr_laurent.create (-1) [Fr.of_string "3"]
    ; Fr_laurent.create 0 []
    ; Fr_laurent.create 1 [Fr.of_string "1"]
    ; Fr_laurent.create 2 [Fr.of_string "2"] ]

let s_poly_output =
  Bivariate_fr_laurent.create (-2)
    [ Fr_laurent.create 0
        [ Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "3"
        ; Fr.of_string "4" ]
    ; Fr_laurent.create 0
        [ Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "1"
        ; Fr.of_string "2" ]
    ; Fr_laurent.create 0 []
    ; Fr_laurent.create 0
        [ Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "5"
        ; Fr.of_string "6" ]
    ; Fr_laurent.create 0
        [ Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "7"
        ; Fr.of_string "8" ]
    ; Fr_laurent.create (-1)
        [ Fr.of_string "-1"
        ; Fr.of_string "0"
        ; Fr.of_string "-1"
        ; Fr.of_string "0"
        ; Fr.of_string "9"
        ; Fr.of_string "10" ]
    ; Fr_laurent.create (-2)
        [ Fr.of_string "-1"
        ; Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "0"
        ; Fr.of_string "-1"
        ; Fr.of_string "11"
        ; Fr.of_string "12" ] ]

let%test_unit "s_poly_test" =
  assert (Bivariate_fr_laurent.equal (s_poly example_weights) s_poly_output)

let%test_unit "r_poly_test" =
  assert (Bivariate_fr_laurent.equal (r_poly example_assignment) r_poly_output)
