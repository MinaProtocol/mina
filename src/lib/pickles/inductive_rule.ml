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

type 'public_input main_input = { public_input : 'public_input }

type ('prev_vars, 'widths, 'public_output, 'auxiliary_output) main_return =
  { previous_proof_statements :
      ('prev_vars, 'widths) Pickles_types.Hlist.H2.T(Previous_proof_statement).t
  ; public_output : 'public_output
  ; auxiliary_output : 'auxiliary_output
  }

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
  ; prevs :
      ( 'prev_vars
      , 'prev_values
      , 'widths
      , 'heights )
      Pickles_types.Hlist.H4.T(Tag).t
  ; main :
         'a_var main_input
      -> ('prev_vars, 'widths, 'ret_var, 'auxiliary_var) main_return
  ; uses_lookup : bool
  }

module T
    (Statement : Pickles_types.Poly_types.T0)
    (Statement_value : Pickles_types.Poly_types.T0)
    (Return_var : Pickles_types.Poly_types.T0)
    (Return_value : Pickles_types.Poly_types.T0)
    (Auxiliary_var : Pickles_types.Poly_types.T0)
    (Auxiliary_value : Pickles_types.Poly_types.T0) =
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
