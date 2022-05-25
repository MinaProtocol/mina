open Core_kernel
open Pickles_types.Poly_types
open Pickles_types.Hlist

module B = struct
  type t = Impls.Step.Boolean.var
end

module Previous_proof_statement = struct
  type ('prev_var, 'width) t =
    { public_input : 'prev_var
    ; proof : ('width, 'width) Proof.t Impls.Step.As_prover.Ref.t
    ; proof_must_verify : B.t
    }

  module Constant = struct
    type ('prev_value, 'width) t =
      { public_input : 'prev_value
      ; proof : ('width, 'width) Proof.t
      ; proof_must_verify : bool
      }
  end
end

(* This type models an "inductive rule". It includes
   - the list of previous statements which this one assumes
   - the snarky main function
   - an unchecked version of the main function which computes the "should verify" flags that
     allow predecessor proofs to conditionally fail to verify
*)
type ('prev_vars, 'prev_values, 'widths, 'heights, 'a_var, 'a_value) t =
  { identifier : string
  ; prevs : ('prev_vars, 'prev_values, 'widths, 'heights) H4.T(Tag).t
  ; main : 'a_var -> ('prev_vars, 'widths) H2.T(Previous_proof_statement).t
  }

module T (Statement : T0) (Statement_value : T0) = struct
  type nonrec ('prev_vars, 'prev_values, 'widths, 'heights) t =
    ( 'prev_vars
    , 'prev_values
    , 'widths
    , 'heights
    , Statement.t
    , Statement_value.t )
    t
end
