module type Intf = sig
  module B : sig
    type t = Impls.Step.Boolean.var
  end

  type _ proof

  module Previous_proof_statement : sig
    type ('prev_var, 'width) t =
      { public_input : 'prev_var
      ; proof : 'width proof Impls.Step.Typ.prover_value
      ; proof_must_verify : B.t
      }

    module Constant : sig
      type ('prev_value, 'width) t =
        { public_input : 'prev_value
        ; proof : 'width proof
        ; proof_must_verify : bool
        }
    end
  end

  type ( 'var
       , 'value
       , 'input_var
       , 'input_value
       , 'ret_var
       , 'ret_value )
       public_input =
    | Input :
        ('var, 'value) Impls.Step.Typ.t
        -> ('var, 'value, 'var, 'value, unit, unit) public_input
    | Output :
        ('ret_var, 'ret_value) Impls.Step.Typ.t
        -> ('ret_var, 'ret_value, unit, unit, 'ret_var, 'ret_value) public_input
    | Input_and_output :
        ('var, 'value) Impls.Step.Typ.t
        * ('ret_var, 'ret_value) Impls.Step.Typ.t
        -> ( 'var * 'ret_var
           , 'value * 'ret_value
           , 'var
           , 'value
           , 'ret_var
           , 'ret_value )
           public_input

  (** The input type of an inductive rule's main function. *)
  type 'public_input main_input =
    { public_input : 'public_input
          (** The publicly-exposed input to the circuit's main function. *)
    }

  type ('prev_vars, 'widths, 'public_output, 'auxiliary_output) main_return =
    { previous_proof_statements :
        ( 'prev_vars
        , 'widths )
        Pickles_types.Hlist.H2.T(Previous_proof_statement).t
    ; public_output : 'public_output
    ; auxiliary_output : 'auxiliary_output
    }

  module Make (M : sig
    type _ t
  end) : sig
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
          -> ('prev_vars, 'widths, 'ret_var, 'auxiliary_var) main_return M.t
      ; feature_flags : bool Pickles_types.Plonk_types.Features.t
      }

    module T
        (Statement : Pickles_types.Poly_types.T0)
        (Statement_value : Pickles_types.Poly_types.T0)
        (Return_var : Pickles_types.Poly_types.T0)
        (Return_value : Pickles_types.Poly_types.T0)
        (Auxiliary_var : Pickles_types.Poly_types.T0)
        (Auxiliary_value : Pickles_types.Poly_types.T0) : sig
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
  end

  module Promise : sig
    include module type of Make (Promise)
  end

  module Deferred : sig
    include module type of Make (Async_kernel.Deferred)
  end

  include module type of Make (Pickles_types.Hlist.Id)
end

module type Proof_intf = sig
  type 'width t
end

module Make (P : Proof_intf) : Intf

module Kimchi : Intf with type 'width proof = 'width Proof.t
