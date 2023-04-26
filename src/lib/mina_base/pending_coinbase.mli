open Base
open Snark_params.Tick

include
  Pending_coinbase_intf.S
    with type State_stack.Stable.V1.t =
      Mina_wire_types.Mina_base.Pending_coinbase.State_stack.V1.t
     and type Stack_versioned.Stable.V1.t =
      Mina_wire_types.Mina_base.Pending_coinbase.Stack_versioned.V1.t
     and type Hash.t =
      Mina_wire_types.Mina_base.Pending_coinbase.Hash_builder.V1.t
     and type Hash_versioned.Stable.V1.t =
      Mina_wire_types.Mina_base.Pending_coinbase.Hash_versioned.V1.t

module For_tests : sig
  val add_coinbase :
    depth:int -> t -> coinbase:Coinbase.t -> is_new_stack:bool -> t Or_error.t

  val add_coinbase_with_zero_checks :
       t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> coinbase:Coinbase.t
    -> supercharged_coinbase:bool
    -> state_body_hash:field
    -> global_slot:Unsigned.uint32
    -> is_new_stack:bool
    -> t

  val incr_index : depth:int -> t -> is_new_stack:bool -> t Base.Or_error.t

  val add_state :
       depth:int
    -> t
    -> field
    -> Unsigned.uint32
    -> is_new_stack:bool
    -> t Base.Or_error.t

  val create_exn : depth:int -> unit -> t

  val max_coinbase_stack_count : depth:int -> int
end
