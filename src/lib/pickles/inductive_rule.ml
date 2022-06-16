open Core_kernel
open Pickles_types.Poly_types
open Pickles_types.Hlist

module B = struct
  type t = Impls.Step.Boolean.var
end

(** This type relates the types of the input and output types of an inductive
    rule's [main] function to the type of the public input to the resulting
    circuit.
*)
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

(** This type models an "inductive rule". It includes
    - the list of previous statements which this one assumes
    - the snarky main function

    The types parameters are:
    - ['prev_vars] the tuple-list of public input circuit types to the previous
      proofs.
      - For example, [Boolean.var * (Boolean.var * unit)] represents 2 previous
        proofs whose public inputs are booleans
    - ['prev_values] the tuple-list of public input non-circuit types to the
      previous proofs.
      - For example, [bool * (bool * unit)] represents 2 previous proofs whose
        public inputs are booleans.
    - ['widths] is a tuple list of the maximum number of previous proofs each
      previous proof itself had.
      - For example, [Nat.z Nat.s * (Nat.z * unit)] represents 2 previous
        proofs where the first has at most 1 previous proof and the second had
        zero previous proofs.
    - ['heights] is a tuple list of the number of inductive rules in each of
      the previous proofs
      - For example, [Nat.z Nat.s Nat.s * (Nat.z Nat.s * unit)] represents 2
        previous proofs where the first had 2 inductive rules and the second
        had 1.
    - ['a_var] is the in-circuit type of the [main] function's public input.
    - ['a_value] is the out-of-circuit type of the [main] function's public
      input.
    - ['ret_var] is the in-circuit type of the [main] function's public output.
    - ['ret_value] is the out-of-circuit type of the [main] function's public
      output.
    - ['auxiliary_var] is the in-circuit type of the [main] function's
      auxiliary data, to be returned to the prover but not exposed in the
      public input.
    - ['auxiliary_value] is the out-of-circuit type of the [main] function's
      auxiliary data, to be returned to the prover but not exposed in the
      public input.
*)
type ( 'prev_vars
     , 'prev_values
     , 'widths
     , 'heights
     , 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'auxiliary_var
     , 'auxiliary_value )
     t =
  { identifier : string
  ; prevs : ('prev_vars, 'prev_values, 'widths, 'heights) H4.T(Tag).t
  ; main :
         'prev_vars H1.T(Id).t
      -> 'a_var
      -> 'prev_vars H1.T(E01(B)).t * 'ret_var * 'auxiliary_var
  }

module T
    (Statement : T0)
    (Statement_value : T0)
    (Return_var : T0)
    (Return_value : T0)
    (Auxiliary_var : T0)
    (Auxiliary_value : T0) =
struct
  type nonrec ('prev_vars, 'prev_values, 'widths, 'heights) t =
    ( 'prev_vars
    , 'prev_values
    , 'widths
    , 'heights
    , Statement.t
    , Statement_value.t
    , Return_var.t
    , Return_value.t
    , Auxiliary_var.t
    , Auxiliary_value.t )
    t
end
