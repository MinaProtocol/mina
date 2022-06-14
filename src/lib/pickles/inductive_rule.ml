open Core_kernel
open Pickles_types.Poly_types
open Pickles_types.Hlist

module B = struct
  type t = Impls.Step.Boolean.var
end

type ('var, 'value, 'input_var, 'input_value, 'ret_var, 'ret_value) public_input =
  | Input :
      ('var, 'value) Impls.Step.Typ.t
      -> ('var, 'value, 'var, 'value, unit, unit) public_input
  | Output :
      ('ret_var, 'ret_value) Impls.Step.Typ.t
      -> ('ret_var, 'ret_value, unit, unit, 'ret_var, 'ret_value) public_input
  | Input_and_output :
      ('var, 'value) Impls.Step.Typ.t * ('ret_var, 'ret_value) Impls.Step.Typ.t
      -> ( 'var * 'ret_var
         , 'value * 'ret_value
         , 'var
         , 'value
         , 'ret_var
         , 'ret_value )
         public_input

type ('var, 'value) packed_public_input =
  | Packed_public_input :
      ( 'var
      , 'value
      , 'input_var
      , 'input_value
      , 'ret_var
      , 'ret_value )
      public_input
      -> ('var, 'value) packed_public_input

(* This type models an "inductive rule". It includes
   - the list of previous statements which this one assumes
   - the snarky main function
   - an unchecked version of the main function which computes the "should verify" flags that
     allow predecessor proofs to conditionally fail to verify
*)
type ( 'prev_vars
     , 'prev_values
     , 'widths
     , 'heights
     , 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value )
     t =
  { identifier : string
  ; prevs : ('prev_vars, 'prev_values, 'widths, 'heights) H4.T(Tag).t
  ; main :
      'prev_vars H1.T(Id).t -> 'a_var -> 'prev_vars H1.T(E01(B)).t * 'ret_var
  }

module T
    (Statement : T0)
    (Statement_value : T0)
    (Return_var : T0)
    (Return_value : T0) =
struct
  type nonrec ('prev_vars, 'prev_values, 'widths, 'heights) t =
    ( 'prev_vars
    , 'prev_values
    , 'widths
    , 'heights
    , Statement.t
    , Statement_value.t
    , Return_var.t
    , Return_value.t )
    t
end
