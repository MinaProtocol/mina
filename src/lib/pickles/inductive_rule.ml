open Core_kernel
open Pickles_types.Poly_types
open Pickles_types.Hlist

module B = struct
  type t = Impls.Step.Boolean.var
end

(* This type models an "inductive rule". It includes
   - the list of previous statements which this one assumes
   - the snarky main function
   - an unchecked version of the main function which computes the "should verify" flags that
     allow predecessor proofs to conditionally fail to verify
*)
type ( 'prev_vars
     , 'prev_values
     , 'prev_return_vars
     , 'prev_return_values
     , 'widths
     , 'heights
     , 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value )
     t =
  { identifier : string
  ; prevs :
      ( 'prev_vars
      , 'prev_values
      , 'prev_return_vars
      , 'prev_return_values
      , 'widths
      , 'heights )
      H6.T(Tag).t
  ; main :
      'prev_vars H1.T(Id).t -> 'a_var -> 'prev_vars H1.T(E01(B)).t * 'ret_var
  }

module T
    (Statement : T0)
    (Statement_value : T0)
    (Return_var : T0)
    (Return_value : T0) =
struct
  type nonrec ( 'prev_vars
              , 'prev_values
              , 'prev_return_vars
              , 'prev_return_values
              , 'widths
              , 'heights )
              t =
    ( 'prev_vars
    , 'prev_values
    , 'prev_return_vars
    , 'prev_return_values
    , 'widths
    , 'heights
    , Statement.t
    , Statement_value.t
    , Return_var.t
    , Return_value.t )
    t
end
