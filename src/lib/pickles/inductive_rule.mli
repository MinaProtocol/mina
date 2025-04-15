module B : sig
  type t = Impls.Step.Boolean.var
end

module Proof_statement_F(P: sig type _ proof end) : sig
module Previous_proof_statement : sig
  type ('prev_var, 'width) t =
    { public_input : 'prev_var
    ; proof : 'width P.proof Impls.Step.Typ.prover_value
    ; proof_must_verify : B.t
    }

  module Constant : sig
    type ('prev_value, 'width) t =
      { public_input : 'prev_value
      ; proof : 'width P.proof
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

(** The input type of an inductive rule's main function. *)
type 'public_input main_input =
  { public_input : 'public_input
        (** The publicly-exposed input to the circuit's main function. *)
  }

(** The return type of an inductive rule's main function. *)
type ('prev_vars, 'widths, 'public_output, 'auxiliary_output) main_return =
  { previous_proof_statements :
      ('prev_vars, 'widths) Pickles_types.Hlist.H2.T(Previous_proof_statement).t
        (** A list of booleans, determining whether each previous proof must
            verify.
        *)
  ; public_output : 'public_output
        (** The publicly-exposed output from the circuit's main function. *)
  ; auxiliary_output : 'auxiliary_output
        (** The auxiliary output from the circuit's main function. This value
            is returned to the prover, but not exposed to or used by verifiers.
        *)
  }
end

module Make (M : sig
  type _ t
end) (P: sig type _ proof end) : sig
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
  module Proof_statement : module type of Proof_statement_F(P)

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
           'a_var Proof_statement.main_input
        -> ('prev_vars, 'widths, 'ret_var, 'auxiliary_var) Proof_statement.main_return M.t
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

module Kimchi_proof : sig
  type _ proof
  type ('a, 'b) t = ('a, 'b) Proof.t_kimchi
  val proof_eq : ('a proof, (unit, 'a, 'a) Mina_wire_types.Pickles.Concrete_.Proof.with_data) Core_kernel.Type_equal.t
end


module Promise(P: sig type _ proof end) : sig
  include module type of Make (Promise) (P)
end

module Deferred(P: sig type _ proof end) : sig
  include module type of Make (Async_kernel.Deferred) (P)
end

include module type of Make (Pickles_types.Hlist.Id) (Kimchi_proof)

module Kimchi_proof_statement : sig
  module Previous_proof_statement : sig
      type ('prev_var, 'width) t =
        { public_input : 'prev_var
        ; proof : 'width Kimchi_proof.proof Impls.Step.Typ.prover_value
        ; proof_must_verify : B.t
        }

      module Constant : sig
        type ('prev_value, 'width) t =
          { public_input : 'prev_value
          ; proof : 'width Kimchi_proof.proof
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
  
  (** The input type of an inductive rule's main function. *)
  type 'public_input main_input =
    { public_input : 'public_input
          (** The publicly-exposed input to the circuit's main function. *)
    }

  open Pickles_types.Hlist
  
  (** The return type of an inductive rule's main function. *)
  type ('prev_vars, 'widths, 'public_output, 'auxiliary_output) main_return =
    { previous_proof_statements :
        ('prev_vars, 'widths) H2.T(Previous_proof_statement).t
          (** A list of booleans, determining whether each previous proof must
              verify.
          *)
    ; public_output : 'public_output
          (** The publicly-exposed output from the circuit's main function. *)
    ; auxiliary_output : 'auxiliary_output
          (** The auxiliary output from the circuit's main function. This value
              is returned to the prover, but not exposed to or used by verifiers.
          *)
    }
end