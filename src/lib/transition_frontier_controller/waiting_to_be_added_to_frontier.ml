open Core_kernel
open Context

let promote_to ~context:(module Context : CONTEXT)
    ~substate:{ Substate.children; received_via_gossip; status; _ } ~block_vc =
  let breadcrumb =
    match status with
    | Processed b ->
        b
    | _ ->
        failwith "promote_building_breadcrumb: expected to be processed"
  in
  let consensus_state =
    Frontier_base.Breadcrumb.protocol_state_with_hashes breadcrumb
    |> With_hash.data |> Mina_state.Protocol_state.consensus_state
  in
  Option.iter block_vc ~f:(fun valid_cb ->
      accept_gossip ~context:(module Context) ~valid_cb consensus_state ) ;
  Context.write_breadcrumb breadcrumb ;
  Transition_state.Waiting_to_be_added_to_frontier
    { breadcrumb
    ; source = (if received_via_gossip then `Gossip else `Catchup)
    ; children
    }
