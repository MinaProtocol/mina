module Circuit := Kimchi_pasta_snarky_backend.Step_impl

(** Generic addition gate gadget
 *   Constrains left_input + right_input = sum
 *   Returns sum
 *)
val add :
     Circuit.Field.t (* left_input *)
  -> Circuit.Field.t (* right_input *)
  -> Circuit.Field.t
(* sum *)

(** Generic subtraction gate gadget
 *   Constrains left_input - right_input = difference
 *   Returns difference
 *)
val sub :
     Circuit.Field.t (* left_input *)
  -> Circuit.Field.t (* right_input *)
  -> Circuit.Field.t
(* difference *)

(** Generic multiplication gate gadget
 *   Constrains left_input * right_input = product
 *   Returns product
 *)
val mul :
     Circuit.Field.t (* left_input *)
  -> Circuit.Field.t (* right_input *)
  -> Circuit.Field.t
(* product *)
