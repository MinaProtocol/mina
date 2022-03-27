module Tock : sig
  module Full = Pickles.Impls.Wrap
  module Run = Pickles.Impls.Wrap

  val group_map_params :
    unit -> Pickles.Backend.Tick.Field.Stable.Latest.t Group_map.Params.t

  module Proving_key = Pickles__Impls.Wrap_impl.Internal_Basic.Proving_key

  module Verification_key =
    Pickles__Impls.Wrap_impl.Internal_Basic.Verification_key

  type field = Pickles__Impls.Wrap_impl.field

  module R1CS_constraint_system =
    Pickles__Impls.Wrap_impl.Internal_Basic.R1CS_constraint_system

  module Keypair = Pickles__Impls.Wrap_impl.Internal_Basic.Keypair
  module Var = Pickles__Impls.Wrap_impl.Internal_Basic.Var
  module Bigint = Pickles__Impls.Wrap_impl.Internal_Basic.Bigint
  module Constraint = Pickles__Impls.Wrap_impl.Internal_Basic.Constraint
  module Data_spec = Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec
  module Typ = Pickles__Impls.Wrap_impl.Internal_Basic.Typ
  module Boolean = Pickles__Impls.Wrap_impl.Internal_Basic.Boolean
  module Checked = Pickles__Impls.Wrap_impl.Internal_Basic.Checked
  module Field = Pickles__Impls.Wrap_impl.Internal_Basic.Field
  module As_prover = Pickles__Impls.Wrap_impl.Internal_Basic.As_prover
  module Proof_inputs = Pickles__Impls.Wrap_impl.Internal_Basic.Proof_inputs
  module Let_syntax = Pickles__Impls.Wrap_impl.Internal_Basic.Let_syntax

  module Bitstring_checked =
    Pickles__Impls.Wrap_impl.Internal_Basic.Bitstring_checked

  module Handle = Pickles__Impls.Wrap_impl.Internal_Basic.Handle
  module Runner = Pickles__Impls.Wrap_impl.Internal_Basic.Runner

  type response = Snarky_backendless__.Request.response

  val unhandled : response

  type request = Snarky_backendless__.Request.request =
    | With :
        { request : 'a Snarky_backendless__.Request.t
        ; respond : 'a Snarky_backendless__.Request.Response.t -> response
        }
        -> request

  module Handler = Pickles__Impls.Wrap_impl.Internal_Basic.Handler
  module Proof_system = Pickles__Impls.Wrap_impl.Internal_Basic.Proof_system
  module Perform = Pickles__Impls.Wrap_impl.Internal_Basic.Perform

  val assert_ :
       ?label:string
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Constraint.t
    -> (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val assert_all :
       ?label:string
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Constraint.t list
    -> (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val assert_r1cs :
       ?label:string
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Field.Var.t
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Field.Var.t
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Field.Var.t
    -> (unit, 'a) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val assert_square :
       ?label:string
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Field.Var.t
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Field.Var.t
    -> (unit, 'a) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val as_prover :
       (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val mk_lazy :
       ('a, unit) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> ( 'a Core_kernel.Lazy.t
       , 's )
       Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val with_state :
       ?and_then:
         ('s1 -> (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t)
    -> ('s1, 's) Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ('a, 's1) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val next_auxiliary :
    (int, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val request_witness :
       ('var, 'value) Pickles__Impls.Wrap_impl.Internal_Basic.Typ.t
    -> ( 'value Snarky_backendless__.Request.t
       , 's )
       Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ('var, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val perform :
       ( unit Snarky_backendless__.Request.t
       , 's )
       Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val request :
       ?such_that:
         ('var -> (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t)
    -> ('var, 'value) Pickles__Impls.Wrap_impl.Internal_Basic.Typ.t
    -> 'value Snarky_backendless__.Request.t
    -> ('var, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val exists :
       ?request:
         ( 'value Snarky_backendless__.Request.t
         , 's )
         Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ?compute:('value, 's) Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ('var, 'value) Pickles__Impls.Wrap_impl.Internal_Basic.Typ.t
    -> ('var, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val exists_handle :
       ?request:
         ( 'value Snarky_backendless__.Request.t
         , 's )
         Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ?compute:('value, 's) Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ('var, 'value) Pickles__Impls.Wrap_impl.Internal_Basic.Typ.t
    -> ( ('var, 'value) Pickles__Impls.Wrap_impl.Internal_Basic.Handle.t
       , 's )
       Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val handle :
       ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Handler.t
    -> ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val handle_as_prover :
       ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> ( Pickles__Impls.Wrap_impl.Internal_Basic.Handler.t
       , 's )
       Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
    -> ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val if_ :
       Pickles__Impls.Wrap_impl.Internal_Basic.Boolean.var
    -> typ:('var, 'a) Pickles__Impls.Wrap_impl.Internal_Basic.Typ.t
    -> then_:'var
    -> else_:'var
    -> ('var, 'b) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val with_label :
       string
    -> ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val constraint_system :
       exposing:
         ( (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
         , 'a
         , 'k_var
         , 'b )
         Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 'k_var
    -> Pickles__Impls.Wrap_impl.Internal_Basic.R1CS_constraint_system.t

  val with_lens :
       ('whole, 'lens) Snarky_backendless__.Lens.t
    -> ('a, 'lens) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> ('a, 'whole) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t

  val generate_keypair :
       exposing:
         ( (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
         , 'a
         , 'k_var
         , 'b )
         Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 'k_var
    -> Pickles__Impls.Wrap_impl.Internal_Basic.Keypair.t

  val conv :
       ('r_var -> 'r_value)
    -> ( 'r_var
       , 'r_value
       , 'k_var
       , 'k_value )
       Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 'k_var
    -> 'k_value

  val conv_never_use :
       (unit -> 'hack)
    -> ( unit -> 'r_var
       , 'r_value
       , 'k_var
       , 'k_value )
       Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> ('hack -> 'k_var)
    -> 'k_var

  val generate_public_input :
       ( 'a
       , Pickles__Impls.Wrap_impl.Internal_Basic.Field.Vector.t
       , 'b
       , 'k_value )
       Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 'k_value

  val generate_witness :
       ( (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
       , Pickles__Impls.Wrap_impl.Internal_Basic.Proof_inputs.t
       , 'k_var
       , 'k_value )
       Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val generate_witness_conv :
       f:(Pickles__Impls.Wrap_impl.Internal_Basic.Proof_inputs.t -> 'out)
    -> ( (unit, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
       , 'out
       , 'k_var
       , 'k_value )
       Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val run_unchecked :
    ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t -> 's -> 's * 'a

  val run_and_check :
       ( ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.As_prover.t
       , 's )
       Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> 's
    -> ('s * 'a) Core_kernel.Or_error.t

  val check :
       ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> 's
    -> unit Core_kernel.Or_error.t

  val generate_auxiliary_input :
       ( ('a, 's) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
       , unit
       , 'k_var
       , 'k_value )
       Pickles__Impls.Wrap_impl.Internal_Basic.Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val constraint_count :
       ?weight:(Pickles__Impls.Wrap_impl.Internal_Basic.Constraint.t -> int)
    -> ?log:(?start:bool -> string -> int -> unit)
    -> ('a, 'b) Pickles__Impls.Wrap_impl.Internal_Basic.Checked.t
    -> int

  module Test = Pickles__Impls.Wrap_impl.Internal_Basic.Test

  val set_constraint_logger :
       (   ?at_label_boundary:[ `End | `Start ] * string
        -> Pickles__Impls.Wrap_impl.Internal_Basic.Constraint.t
        -> unit)
    -> unit

  val clear_constraint_logger : unit -> unit

  module Number : sig
    type t =
      Snarky_backendless__Number.Make(Pickles.Impls.Wrap.Internal_Basic).t

    val ( + ) : t -> t -> t

    val ( - ) : t -> t -> t

    val ( * ) : t -> t -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val constant : Pickles.Impls.Wrap.Internal_Basic.Field.t -> t

    val one : t

    val zero : t

    val if_ :
         Pickles.Impls.Wrap.Internal_Basic.Boolean.var
      -> then_:t
      -> else_:t
      -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ( < ) :
         t
      -> t
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ( > ) :
         t
      -> t
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ( <= ) :
         t
      -> t
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ( >= ) :
         t
      -> t
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ( = ) :
         t
      -> t
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val min : t -> t -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val max : t -> t -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val to_var : t -> Pickles.Impls.Wrap.Internal_Basic.Field.Var.t

    val of_bits : Pickles.Impls.Wrap.Internal_Basic.Boolean.var list -> t

    val to_bits :
         t
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var list
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val div_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ceil_div_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val mul_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val mod_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val of_pow_2 : [ `Two_to_the of int ] -> t

    val clamp_to_n_bits :
      t -> int -> (t, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t
  end

  module Enumerable : functor
    (M : sig
       type t

       val min : Ppx_deriving_runtime.int

       val max : Ppx_deriving_runtime.int

       val to_enum : t -> Ppx_deriving_runtime.int

       val of_enum : Ppx_deriving_runtime.int -> t Ppx_deriving_runtime.option
     end)
    -> sig
    val bit_length : int

    type var = Pickles.Impls.Wrap.Internal_Basic.Field.Var.t

    val typ : (var, M.t) Pickles.Impls.Wrap.Internal_Basic.Typ.t

    val to_bits : M.t -> bool list

    val var : M.t -> var

    val assert_equal :
      var -> var -> (unit, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val var_to_bits :
         var
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var list
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val if_ :
         Pickles.Impls.Wrap.Internal_Basic.Boolean.var
      -> then_:var
      -> else_:var
      -> (var, 'a) Pickles.Impls.Wrap.Internal_Basic.Checked.t

    val ( = ) :
         var
      -> var
      -> ( Pickles.Impls.Wrap.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Wrap.Internal_Basic.Checked.t
  end

  module Inner_curve = Pickles.Backend.Tock.Inner_curve
end

module Tick : sig
  module Full = Pickles.Impls.Step
  module Run = Pickles.Impls.Step

  val group_map_params : Pickles.Backend.Tock.Field.t Group_map.Params.t

  module Proving_key = Pickles__Impls.Step.Impl.Internal_Basic.Proving_key

  module Verification_key =
    Pickles__Impls.Step.Impl.Internal_Basic.Verification_key

  type field = Pickles__Impls.Step.Impl.field

  module R1CS_constraint_system =
    Pickles__Impls.Step.Impl.Internal_Basic.R1CS_constraint_system

  module Keypair = Pickles__Impls.Step.Impl.Internal_Basic.Keypair
  module Var = Pickles__Impls.Step.Impl.Internal_Basic.Var
  module Bigint = Pickles__Impls.Step.Impl.Internal_Basic.Bigint
  module Constraint = Pickles__Impls.Step.Impl.Internal_Basic.Constraint
  module Data_spec = Pickles__Impls.Step.Impl.Internal_Basic.Data_spec
  module Typ = Pickles__Impls.Step.Impl.Internal_Basic.Typ
  module Boolean = Pickles__Impls.Step.Impl.Internal_Basic.Boolean
  module Checked = Pickles__Impls.Step.Impl.Internal_Basic.Checked
  module Field = Pickles__Impls.Step.Impl.Internal_Basic.Field
  module As_prover = Pickles__Impls.Step.Impl.Internal_Basic.As_prover
  module Proof_inputs = Pickles__Impls.Step.Impl.Internal_Basic.Proof_inputs
  module Let_syntax = Pickles__Impls.Step.Impl.Internal_Basic.Let_syntax

  module Bitstring_checked =
    Pickles__Impls.Step.Impl.Internal_Basic.Bitstring_checked

  module Handle = Pickles__Impls.Step.Impl.Internal_Basic.Handle
  module Runner = Pickles__Impls.Step.Impl.Internal_Basic.Runner

  type response = Tock.response

  val unhandled : response

  type request = Tock.request =
    | With :
        { request : 'a Snarky_backendless__.Request.t
        ; respond : 'a Snarky_backendless__.Request.Response.t -> response
        }
        -> request

  module Handler = Pickles__Impls.Step.Impl.Internal_Basic.Handler
  module Proof_system = Pickles__Impls.Step.Impl.Internal_Basic.Proof_system
  module Perform = Pickles__Impls.Step.Impl.Internal_Basic.Perform

  val assert_ :
       ?label:string
    -> Pickles__Impls.Step.Impl.Internal_Basic.Constraint.t
    -> (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val assert_all :
       ?label:string
    -> Pickles__Impls.Step.Impl.Internal_Basic.Constraint.t list
    -> (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val assert_r1cs :
       ?label:string
    -> Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
    -> Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
    -> Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
    -> (unit, 'a) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val assert_square :
       ?label:string
    -> Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
    -> Pickles__Impls.Step.Impl.Internal_Basic.Field.Var.t
    -> (unit, 'a) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val as_prover :
       (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val mk_lazy :
       ('a, unit) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> ( 'a Core_kernel.Lazy.t
       , 's )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val with_state :
       ?and_then:
         ('s1 -> (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t)
    -> ('s1, 's) Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ('a, 's1) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val next_auxiliary :
    (int, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val request_witness :
       ('var, 'value) Pickles__Impls.Step.Impl.Internal_Basic.Typ.t
    -> ( 'value Snarky_backendless__.Request.t
       , 's )
       Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ('var, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val perform :
       ( unit Snarky_backendless__.Request.t
       , 's )
       Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val request :
       ?such_that:
         ('var -> (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t)
    -> ('var, 'value) Pickles__Impls.Step.Impl.Internal_Basic.Typ.t
    -> 'value Snarky_backendless__.Request.t
    -> ('var, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val exists :
       ?request:
         ( 'value Snarky_backendless__.Request.t
         , 's )
         Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ?compute:('value, 's) Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ('var, 'value) Pickles__Impls.Step.Impl.Internal_Basic.Typ.t
    -> ('var, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val exists_handle :
       ?request:
         ( 'value Snarky_backendless__.Request.t
         , 's )
         Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ?compute:('value, 's) Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ('var, 'value) Pickles__Impls.Step.Impl.Internal_Basic.Typ.t
    -> ( ('var, 'value) Pickles__Impls.Step.Impl.Internal_Basic.Handle.t
       , 's )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val handle :
       ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> Pickles__Impls.Step.Impl.Internal_Basic.Handler.t
    -> ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val handle_as_prover :
       ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> ( Pickles__Impls.Step.Impl.Internal_Basic.Handler.t
       , 's )
       Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
    -> ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val if_ :
       Pickles__Impls.Step.Impl.Internal_Basic.Boolean.var
    -> typ:('var, 'a) Pickles__Impls.Step.Impl.Internal_Basic.Typ.t
    -> then_:'var
    -> else_:'var
    -> ('var, 'b) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val with_label :
       string
    -> ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val constraint_system :
       exposing:
         ( (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
         , 'a
         , 'k_var
         , 'b )
         Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 'k_var
    -> Pickles__Impls.Step.Impl.Internal_Basic.R1CS_constraint_system.t

  val with_lens :
       ('whole, 'lens) Snarky_backendless__.Lens.t
    -> ('a, 'lens) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> ('a, 'whole) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val generate_keypair :
       exposing:
         ( (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
         , 'a
         , 'k_var
         , 'b )
         Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 'k_var
    -> Pickles__Impls.Step.Impl.Internal_Basic.Keypair.t

  val conv :
       ('r_var -> 'r_value)
    -> ( 'r_var
       , 'r_value
       , 'k_var
       , 'k_value )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 'k_var
    -> 'k_value

  val conv_never_use :
       (unit -> 'hack)
    -> ( unit -> 'r_var
       , 'r_value
       , 'k_var
       , 'k_value )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> ('hack -> 'k_var)
    -> 'k_var

  val generate_public_input :
       ( 'a
       , Pickles__Impls.Step.Impl.Internal_Basic.Field.Vector.t
       , 'b
       , 'k_value )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 'k_value

  val generate_witness :
       ( (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
       , Pickles__Impls.Step.Impl.Internal_Basic.Proof_inputs.t
       , 'k_var
       , 'k_value )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val generate_witness_conv :
       f:(Pickles__Impls.Step.Impl.Internal_Basic.Proof_inputs.t -> 'out)
    -> ( (unit, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
       , 'out
       , 'k_var
       , 'k_value )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val run_unchecked :
    ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t -> 's -> 's * 'a

  val run_and_check :
       ( ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.As_prover.t
       , 's )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> 's
    -> ('s * 'a) Core_kernel.Or_error.t

  val check :
       ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> 's
    -> unit Core_kernel.Or_error.t

  val generate_auxiliary_input :
       ( ('a, 's) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
       , unit
       , 'k_var
       , 'k_value )
       Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val constraint_count :
       ?weight:(Pickles__Impls.Step.Impl.Internal_Basic.Constraint.t -> int)
    -> ?log:(?start:bool -> string -> int -> unit)
    -> ('a, 'b) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
    -> int

  module Test = Pickles__Impls.Step.Impl.Internal_Basic.Test

  val set_constraint_logger :
       (   ?at_label_boundary:[ `End | `Start ] * string
        -> Pickles__Impls.Step.Impl.Internal_Basic.Constraint.t
        -> unit)
    -> unit

  val clear_constraint_logger : unit -> unit

  module Number : sig
    type t =
      Snarky_backendless__Number.Make(Pickles.Impls.Step.Internal_Basic).t

    val ( + ) : t -> t -> t

    val ( - ) : t -> t -> t

    val ( * ) : t -> t -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val constant : Pickles.Impls.Step.Internal_Basic.Field.t -> t

    val one : t

    val zero : t

    val if_ :
         Pickles.Impls.Step.Internal_Basic.Boolean.var
      -> then_:t
      -> else_:t
      -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val ( < ) :
         t
      -> t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val ( > ) :
         t
      -> t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val ( <= ) :
         t
      -> t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val ( >= ) :
         t
      -> t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val ( = ) :
         t
      -> t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val min : t -> t -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val max : t -> t -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val to_var : t -> Pickles.Impls.Step.Internal_Basic.Field.Var.t

    val of_bits : Pickles.Impls.Step.Internal_Basic.Boolean.var list -> t

    val to_bits :
         t
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var list
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val div_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val ceil_div_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val mul_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val mod_pow_2 :
         t
      -> [ `Two_to_the of int ]
      -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val of_pow_2 : [ `Two_to_the of int ] -> t

    val clamp_to_n_bits :
      t -> int -> (t, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t
  end

  module Enumerable : functor
    (M : sig
       type t

       val min : Ppx_deriving_runtime.int

       val max : Ppx_deriving_runtime.int

       val to_enum : t -> Ppx_deriving_runtime.int

       val of_enum : Ppx_deriving_runtime.int -> t Ppx_deriving_runtime.option
     end)
    -> sig
    val bit_length : int

    type var = Pickles.Impls.Step.Internal_Basic.Field.Var.t

    val typ : (var, M.t) Pickles.Impls.Step.Internal_Basic.Typ.t

    val to_bits : M.t -> bool list

    val var : M.t -> var

    val assert_equal :
      var -> var -> (unit, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val var_to_bits :
         var
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var list
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t

    val if_ :
         Pickles.Impls.Step.Internal_Basic.Boolean.var
      -> then_:var
      -> else_:var
      -> (var, 'a) Pickles.Impls.Step.Internal_Basic.Checked.t

    val ( = ) :
         var
      -> var
      -> ( Pickles.Impls.Step.Internal_Basic.Boolean.var
         , 'a )
         Pickles.Impls.Step.Internal_Basic.Checked.t
  end

  module Inner_curve = Pickles.Backend.Tick.Inner_curve
end
