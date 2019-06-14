open Snarkette.Mnt6_80
open Arithmetic_circuit
open Constraints
open Laurent
module Fr = Snarkette.Mnt4_80.Fq
module Fr_laurent = Make_laurent (N) (Fr)
module Bivariate_Fr_laurent = Make_laurent (N) (Fr_laurent)

let (example_assignment : Assignment.t) =
  { aL= [Fr.of_string "1"; Fr.of_string "2"]
  ; aR= [Fr.of_string "3"; Fr.of_string "4"]
  ; aO= [Fr.of_string "5"; Fr.of_string "6"] }

let (example_weights : Gate_weights.t) =
  { wL=
      [ [Fr.of_string "1"; Fr.of_string "2"]
      ; [Fr.of_string "3"; Fr.of_string "4"] ]
  ; wR=
      [ [Fr.of_string "5"; Fr.of_string "6"]
      ; [Fr.of_string "7"; Fr.of_string "8"] ]
  ; wO=
      [ [Fr.of_string "9"; Fr.of_string "10"]
      ; [Fr.of_string "11"; Fr.of_string "12"] ] }

let r_poly_output =
  Bivariate_Fr_laurent.create (-4)
    [ Fr_laurent.create (-4) [Fr.of_string "6"]
    ; Fr_laurent.create (-3) [Fr.of_string "5"]
    ; Fr_laurent.create (-2) [Fr.of_string "4"]
    ; Fr_laurent.create (-1) [Fr.of_string "3"]
    ; Fr_laurent.create 0 []
    ; Fr_laurent.create 1 [Fr.of_string "1"]
    ; Fr_laurent.create 2 [Fr.of_string "2"] ]

let s_poly_output =
  Bivariate_Fr_laurent.create (-2)
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
  assert (Bivariate_Fr_laurent.equal (s_poly example_weights) s_poly_output)

let%test_unit "r_poly_test" =
  assert (Bivariate_Fr_laurent.equal (r_poly example_assignment) r_poly_output)
