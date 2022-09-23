open Core_kernel

module Make
    (Engine : Intf.Engine.S)
    (Event_router : Intf.Dsl.Event_router_intf with module Engine := Engine)
    (Network_state : Intf.Dsl.Network_state_intf
                       with module Engine := Engine
                        and module Event_router := Event_router) : sig
  type 'a predicate_result =
    | Predicate_passed
    | Predicate_continuation of 'a
    | Predicate_failure of Error.t

  type predicate =
    | Network_state_predicate :
        (Network_state.t -> 'a predicate_result)
        * ('a -> Network_state.t -> 'a predicate_result)
        -> predicate
    | Event_predicate :
        'b Event_type.t
        * 'a
        * ('a -> Engine.Network.Node.t -> 'b -> 'a predicate_result)
        -> predicate

  type wait_condition_id =
    | Nodes_to_initialize
    | Blocks_to_be_produced
    | Nodes_to_synchronize
    | Signed_command_to_be_included_in_frontier
    | Ledger_proofs_emitted_since_genesis
    | Block_height_growth
    | Zkapp_to_be_included_in_frontier
    | Persisted_frontier_loaded

  type t =
    { id : wait_condition_id
    ; description : string
    ; predicate : predicate
    ; soft_timeout : Network_time_span.t
    ; hard_timeout : Network_time_span.t
    }

  include
    Intf.Dsl.Wait_condition_intf
      with type t := t
       and module Engine := Engine
       and type wait_condition_id := wait_condition_id
       and module Event_router := Event_router
       and module Network_state := Network_state
end
