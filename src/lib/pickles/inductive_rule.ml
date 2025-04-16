open Pickles_types.Poly_types
open Pickles_types.Hlist

module B = struct
  type t = Impls.Step.Boolean.var
end

module type Proof_intf = sig
  type 'width t
end

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

  (** This type relates the types of the input and output types of an inductive
    rule's [main] function to the type of the public input to the resulting
    circuit.
*)
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
        ('prev_vars, 'widths) H2.T(Previous_proof_statement).t
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
      ; prevs : ('prev_vars, 'prev_values, 'widths, 'heights) H4.T(Tag).t
      ; main :
             'a_var main_input
          -> ('prev_vars, 'widths, 'ret_var, 'auxiliary_var) main_return M.t
      ; feature_flags : bool Pickles_types.Plonk_types.Features.t
      }

    module T
        (Statement : T0)
        (Statement_value : T0)
        (Return_var : T0)
        (Return_value : T0)
        (Auxiliary_var : T0)
        (Auxiliary_value : T0) : sig
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

module Make (P : Proof_intf) : Intf with type 'a proof = 'a P.t = struct
  module B = struct
    type t = Impls.Step.Boolean.var
  end

  type 'a proof = 'a P.t

  module Previous_proof_statement = struct
    type ('prev_var, 'width) t =
      { public_input : 'prev_var
      ; proof : 'width P.t Impls.Step.Typ.prover_value
      ; proof_must_verify : B.t
      }

    module Constant = struct
      type ('prev_value, 'width) t =
        { public_input : 'prev_value
        ; proof : 'width P.t
        ; proof_must_verify : bool
        }
    end
  end

  (** This type relates the types of the input and output types of an inductive
    rule's [main] function to the type of the public input to the resulting
    circuit.
*)
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

  (** The return type of an inductive rule's main function. *)
  type ('prev_vars, 'widths, 'public_output, 'auxiliary_output) main_return =
    { previous_proof_statements :
        ('prev_vars, 'widths) H2.T(Previous_proof_statement).t
    ; public_output : 'public_output
    ; auxiliary_output : 'auxiliary_output
    }

  module Make (M : sig
    type _ t
  end) =
  struct
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
             'a_var main_input
          -> ('prev_vars, 'widths, 'ret_var, 'auxiliary_var) main_return M.t
      ; feature_flags : bool Pickles_types.Plonk_types.Features.t
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
  end

  module Promise = Make (Promise)
  module Deferred = Make (Async_kernel.Deferred)

  (* This is the key fix - we need to include the Id-based module to match the MLI *)
  include Make (Id)
end

module Kimchi = Make (Proof)
