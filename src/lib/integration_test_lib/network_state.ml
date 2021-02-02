open Async_kernel
open Core_kernel
open Pipe_lib
open Mina_base

module Make
    (Engine : Intf.Engine.S)
    (Event_router : Intf.Dsl.Event_router_intf with module Engine := Engine) :
  Intf.Dsl.Network_state_intf
  with module Engine := Engine
   and module Event_router := Event_router = struct
  module Node = Engine.Network.Node

  (* TODO: Just replace the first 3 fields here with Protocol_state *)
  type t =
    { block_height: int
    ; epoch: int
    ; global_slot: int
    ; snarked_ledgers_generated: int
    ; blocks_generated: int
    ; node_initialization: bool String.Map.t
    ; best_tips_by_node: State_hash.t String.Map.t }

  let empty =
    { block_height= 0
    ; epoch= 0
    ; global_slot= 0
    ; snarked_ledgers_generated= 0
    ; blocks_generated= 0
    ; node_initialization= String.Map.empty
    ; best_tips_by_node= String.Map.empty }

  let listen ~logger event_router =
    let r, w = Broadcast_pipe.create empty in
    let update ~f =
      (* should be safe to ignore the write here, so long as `f` is synchronous *)
      ignore (Broadcast_pipe.Writer.write w (f (Broadcast_pipe.Reader.peek r))) ;
      Deferred.return `Continue
    in
    ignore
      (Event_router.on event_router Event_type.Block_produced
         ~f:(fun node block_produced ->
           update ~f:(fun state ->
               [%log debug] "handling block production from $node"
                 ~metadata:[("node", `String (Node.id node))] ;
               if block_produced.block_height > state.block_height then
                 let snarked_ledgers_generated =
                   if block_produced.snarked_ledger_generated then 1 else 0
                 in
                 { state with
                   epoch= block_produced.global_slot
                 ; global_slot= block_produced.global_slot
                 ; block_height= block_produced.block_height
                 ; blocks_generated= state.blocks_generated + 1
                 ; snarked_ledgers_generated=
                     state.snarked_ledgers_generated
                     + snarked_ledgers_generated }
               else state ) )) ;
    ignore
      (Event_router.on event_router
         Event_type.Transition_frontier_diff_application
         ~f:(fun node diff_application ->
           update ~f:(fun state ->
               [%log debug] "handling frontier diff application of $node"
                 ~metadata:[("node", `String (Node.id node))] ;
               Option.value_map diff_application.best_tip_changed
                 ~default:state ~f:(fun new_best_tip ->
                   let best_tips_by_node' =
                     String.Map.set state.best_tips_by_node ~key:(Node.id node)
                       ~data:new_best_tip
                   in
                   {state with best_tips_by_node= best_tips_by_node'} ) ) )) ;
    ignore
      (Event_router.on event_router Event_type.Node_initialization
         ~f:(fun node () ->
           update ~f:(fun state ->
               [%log debug] "handling initialization of $node"
                 ~metadata:[("node", `String (Node.id node))] ;
               let node_initialization' =
                 String.Map.set state.node_initialization ~key:(Node.id node)
                   ~data:true
               in
               {state with node_initialization= node_initialization'} ) )) ;
    (r, w)
end
