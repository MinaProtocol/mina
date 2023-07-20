(** Generic addition gate gadget
 *   Constrains left_input + right_input = sum
 *   Returns sum
 *)
val add :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* left_input *)
  -> 'f Snarky_backendless.Cvar.t (* right_input *)
  -> 'f Snarky_backendless.Cvar.t
(* sum *)

(** Generic constant addition gate gadget
 *   Constrains left_input + right_input = sum, where the right operand is constant.
 *   Returns sum
 *)
val add_const :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* left_input *)
  -> 'f (* right_input *)
  -> 'f Snarky_backendless.Cvar.t
(* sum *)

(** Generic subtraction gate gadget
 *   Constrains left_input - right_input = difference
 *   Returns difference
 *)
val sub :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* left_input *)
  -> 'f Snarky_backendless.Cvar.t (* right_input *)
  -> 'f Snarky_backendless.Cvar.t
(* difference *)

(** Generic multiplication gate gadget
 *   Constrains left_input * right_input = product
 *   Returns product
 *)
val mul :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* left_input *)
  -> 'f Snarky_backendless.Cvar.t (* right_input *)
  -> 'f Snarky_backendless.Cvar.t
(* product *)
