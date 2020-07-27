open Core_kernel
open Pickles_types

type ('var, 'value, 'n1, 'n2) tag = ('var * 'value * 'n1 * 'n2) Type_equal.Id.t

type kind = Side_loaded | Compiled

type ('var, 'value, 'n1, 'n2) t = {kind: kind; id: ('var, 'value, 'n1, 'n2) tag}
[@@deriving fields]

(*
  | Side_loaded
    of { step_upper_bounds: Domains.t
       ; wrap_upper_bounds: Domains.t
       ; max_branching: (module Nat.Add.Intf with type n = 'n1)
       ; value_to_field_elements : 'value -> Impls.Step.Field.Constant.t array
       ; var_to_field_elements : 'var -> Impls.Step.Field.t array
       ; typ: ('var, 'value) Impls.Step.Typ.t
       ; id: ('var , 'value , 'n1 , 'n2) tag
       }
  | Compiled of ('var , 'value , 'n1 , 'n2) tag

*)

let create ~name =
  {kind= Compiled; id= Type_equal.Id.create ~name sexp_of_opaque}

let side_loaded id = {kind= Side_loaded; id}

(* For coda, an out of band verification key may have:
   - Up to 8 branches
   - Step, wrap domains <= 2 * URS size

   How do the actual domains get passed into the circuit though...

   For now just have a mutable API.
*)
