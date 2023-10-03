open Async_kernel
open Core_kernel
open Pipe_lib
open Mina_base
open Mina_transaction

module Make
    (Engine : Intf.Engine.S)
    (Event_router : Intf.Dsl.Event_router_intf with module Engine := Engine) :
  Intf.Dsl.Network_state_intf
    with module Engine := Engine
     and module Event_router := Event_router = struct
  module Node = Engine.Network.Node

  let set_to_yojson ~(element : 'a -> Yojson.Safe.t) s : Yojson.Safe.t =
    `List (List.map ~f:element (State_hash.Set.to_list s))

  let map_to_yojson ~(f_key_to_string : 'a -> string) ~f_value_to_yojson m :
      Yojson.Safe.t =
    `Assoc
      ( Map.to_alist m
      |> List.map ~f:(fun (k, v) -> (f_key_to_string k, f_value_to_yojson v)) )

  (* TODO: Just replace the first 3 fields here with Protocol_state *)
  type t =
    { block_height : int
    ; epoch : int
    ; global_slot : int
    ; snarked_ledgers_generated : int
    ; blocks_generated : int
    ; num_transition_frontier_loaded_from_persistence : int
    ; num_persisted_frontier_loaded : int
    ; num_persisted_frontier_fresh_boot : int
    ; num_bootstrap_required : int
    ; num_persisted_frontier_dropped : int
    ; node_on : bool String.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:ident ~f_value_to_yojson:(fun b ->
                `Bool b )]
    ; node_initialization : bool String.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:ident ~f_value_to_yojson:(fun b ->
                `Bool b )]
    ; gossip_received : Gossip_state.t String.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:ident
              ~f_value_to_yojson:Gossip_state.to_yojson]
    ; best_tips_by_node : State_hash.t String.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:ident
              ~f_value_to_yojson:State_hash.to_yojson]
    ; blocks_produced_by_node : State_hash.t list String.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:ident ~f_value_to_yojson:(fun ls ->
                `List (List.map State_hash.to_yojson ls) )]
    ; blocks_seen_by_node : State_hash.Set.t String.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:ident ~f_value_to_yojson:(fun set ->
                `List
                  (State_hash.Set.to_list set |> List.map State_hash.to_yojson) )]
    ; blocks_including_txn : State_hash.Set.t Transaction_hash.Map.t
          [@to_yojson
            map_to_yojson ~f_key_to_string:Transaction_hash.to_base58_check
              ~f_value_to_yojson:(set_to_yojson ~element:State_hash.to_yojson)]
    }
  [@@deriving to_yojson]

  let empty =
    { block_height = 0
    ; epoch = 0
    ; global_slot = 0
    ; snarked_ledgers_generated = 0
    ; blocks_generated = 0
    ; node_on = String.Map.empty
    ; node_initialization = String.Map.empty
    ; gossip_received = String.Map.empty
    ; best_tips_by_node = String.Map.empty
    ; blocks_produced_by_node = String.Map.empty
    ; blocks_seen_by_node = String.Map.empty
    ; blocks_including_txn = Transaction_hash.Map.empty
    ; num_transition_frontier_loaded_from_persistence = 0
    ; num_persisted_frontier_loaded = 0
    ; num_persisted_frontier_fresh_boot = 0
    ; num_bootstrap_required = 0
    ; num_persisted_frontier_dropped = 0
    }

  let listen ~logger event_router =
    let reader, writer = Broadcast_pipe.create empty in
    let update ~f =
      (* should be safe to ignore the write here, so long as `f` is synchronous *)
      let state = f (Broadcast_pipe.Reader.peek reader) in
      [%log debug] "updated network state to: $state"
        ~metadata:[ ("state", to_yojson state) ] ;
      ignore (Broadcast_pipe.Writer.write writer state : unit Deferred.t) ;
      Deferred.return `Continue
    in
    (* handle_block_produced *)
    ignore
      ( Event_router.on event_router Event_type.Block_produced
          ~f:(fun node block_produced ->
            [%log debug] "Updating network state with block produced event"
              ~metadata:
                [ ( "snark_ledger_generated"
                  , `Bool block_produced.snarked_ledger_generated )
                ] ;
            update ~f:(fun state ->
                [%log debug] "handling block production from $node"
                  ~metadata:[ ("node", `String (Node.infra_id node)) ] ;
                if block_produced.block_height > state.block_height then
                  let snarked_ledgers_generated =
                    if block_produced.snarked_ledger_generated then 1 else 0
                  in
                  let blocks_produced_by_node_map =
                    Core.String.Map.update state.blocks_produced_by_node
                      (Node.id node) ~f:(fun ls_opt ->
                        match ls_opt with
                        | None ->
                            [ block_produced.state_hash ]
                        | Some ls ->
                            List.cons block_produced.state_hash ls )
                  in
                  { state with
                    epoch = block_produced.global_slot
                  ; global_slot = block_produced.global_slot
                  ; block_height = block_produced.block_height
                  ; blocks_generated = state.blocks_generated + 1
                  ; snarked_ledgers_generated =
                      state.snarked_ledgers_generated
                      + snarked_ledgers_generated
                  ; blocks_produced_by_node = blocks_produced_by_node_map
                  }
                else state ) )
        : _ Event_router.event_subscription ) ;
    (* handle_update_best_tips *)
    ignore
      ( Event_router.on event_router
          Event_type.Transition_frontier_diff_application
          ~f:(fun node diff_application ->
            [%log debug]
              "Updating network state with transition frontier diff \
               application event" ;
            update ~f:(fun state ->
                [%log debug] "handling frontier diff application of $node"
                  ~metadata:[ ("node", `String (Node.infra_id node)) ] ;
                Option.value_map diff_application.best_tip_changed
                  ~default:state ~f:(fun new_best_tip ->
                    let best_tips_by_node' =
                      String.Map.set state.best_tips_by_node ~key:(Node.id node)
                        ~data:new_best_tip
                    in
                    { state with best_tips_by_node = best_tips_by_node' } ) ) )
        : _ Event_router.event_subscription ) ;
    let handle_gossip_received event_type =
      ignore
        ( Event_router.on event_router event_type
            ~f:(fun node gossip_with_direction ->
              update ~f:(fun state ->
                  { state with
                    gossip_received =
                      Map.update state.gossip_received (Node.id node)
                        ~f:(fun gossip_state_opt ->
                          let gossip_state =
                            match gossip_state_opt with
                            | None ->
                                Gossip_state.create (Node.id node)
                            | Some state ->
                                state
                          in
                          [%log debug]
                            "GOSSIP RECEIVED node: $node.  event: $event"
                            ~metadata:
                              [ ("node", `String (Node.infra_id node))
                              ; ( "event"
                                , Event_type.event_to_yojson
                                    (Event_type.Event
                                       (event_type, gossip_with_direction) ) )
                              ] ;
                          Gossip_state.add gossip_state event_type
                            gossip_with_direction ;
                          gossip_state )
                  } ) )
          : _ Event_router.event_subscription )
    in
    handle_gossip_received Block_gossip ;
    handle_gossip_received Snark_work_gossip ;
    handle_gossip_received Transactions_gossip ;
    (* handle_node_on *)
    ignore
      ( Event_router.on event_router Event_type.Node_started ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with event of $node being started"
                  ~metadata:[ ("node", `String (Node.id node)) ] ;
                let node_on' =
                  String.Map.set state.node_on ~key:(Node.id node) ~data:true
                in
                { state with node_on = node_on' } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_node_init *)
    ignore
      ( Event_router.on event_router Event_type.Node_initialization
          ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with initialization event of $node"
                  ~metadata:[ ("node", `String (Node.infra_id node)) ] ;
                let node_initialization' =
                  String.Map.set state.node_initialization ~key:(Node.id node)
                    ~data:true
                in
                { state with node_initialization = node_initialization' } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_persisted_frontier_loaded *)
    ignore
      ( Event_router.on event_router Event_type.Persisted_frontier_loaded
          ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with persisted frontier loaded event \
                   of $node"
                  ~metadata:[ ("node", `String (Node.id node)) ] ;
                { state with
                  num_persisted_frontier_loaded =
                    state.num_persisted_frontier_loaded + 1
                } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_persisted_frontier_fresh_boot *)
    ignore
      ( Event_router.on event_router Event_type.Persisted_frontier_fresh_boot
          ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with persisted frontier fresh boot \
                   event of $node"
                  ~metadata:[ ("node", `String (Node.id node)) ] ;
                { state with
                  num_persisted_frontier_fresh_boot =
                    state.num_persisted_frontier_fresh_boot + 1
                } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_bootstrap_required *)
    ignore
      ( Event_router.on event_router Event_type.Bootstrap_required
          ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with bootstrap required event of \
                   $node"
                  ~metadata:[ ("node", `String (Node.id node)) ] ;
                { state with
                  num_bootstrap_required = state.num_bootstrap_required + 1
                } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_persisted_frontier_dropped *)
    ignore
      ( Event_router.on event_router Event_type.Persisted_frontier_dropped
          ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with persisted frontier dropped \
                   event of $node"
                  ~metadata:[ ("node", `String (Node.id node)) ] ;
                { state with
                  num_persisted_frontier_dropped =
                    state.num_persisted_frontier_dropped + 1
                } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_transition frontier loaded *)
    ignore
      ( Event_router.on event_router
          Event_type.Transition_frontier_loaded_from_persistence
          ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with transition frontier loaded \
                   event of $node"
                  ~metadata:[ ("node", `String (Node.id node)) ] ;
                { state with
                  num_transition_frontier_loaded_from_persistence =
                    state.num_transition_frontier_loaded_from_persistence + 1
                } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_node_stopped *)
    ignore
      ( Event_router.on event_router Event_type.Node_stopped ~f:(fun node () ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with event of $node being stopped \
                   deliberately"
                  ~metadata:[ ("node", `String (Node.infra_id node)) ] ;

                let node_initialization' =
                  String.Map.set state.node_initialization ~key:(Node.id node)
                    ~data:false
                in
                let node_on' =
                  String.Map.set state.node_on ~key:(Node.id node) ~data:false
                in
                let best_tips_by_node' =
                  String.Map.remove state.best_tips_by_node (Node.id node)
                in
                { state with
                  node_initialization = node_initialization'
                ; node_on = node_on'
                ; best_tips_by_node = best_tips_by_node'
                } ) )
        : _ Event_router.event_subscription ) ;
    (* handle_node_down *)
    ignore
      ( Event_router.on event_router Event_type.Node_down ~f:(fun node () ->
            [%log debug] "received Node_down event from $node"
              ~metadata:[ ("node", `String (Node.id node)) ] ;

            let state = Broadcast_pipe.Reader.peek reader in
            if
              not (String.Map.find_exn state.node_initialization (Node.id node))
            then
              let () =
                [%log debug]
                  "Lucy cannot contact $node, but all is well because this \
                   node was stopped deliberately or just hasn't initialized \
                   yet"
                  ~metadata:[ ("node", `String (Node.id node)) ]
              in
              update ~f:(fun state -> state)
            else
              let () =
                [%log fatal]
                  "Lucy has lost contact with $node, without the node being \
                   deliberately stopped.  Aborting the test because a node \
                   went down unexpectedly."
                  ~metadata:[ ("node", `String (Node.id node)) ]
              in

              failwith
                "Aborting the test because a node went down unexpectedly."
            (* let () =
                 [%log info]
                   "Lucy has lost contact with $node, without the node being \
                    deliberately stopped, meaning that the node crashed or was \
                    somehow taken down.  Lucy will attempt to recover and \
                    restart this node."
                   ~metadata:[ ("node", `String (Node.id node)) ]
               in
               let (_ : [> `Continue ] Deferred.t) =
                 update ~f:(fun state ->
                     let node_initialization' =
                       (* we're about to restart the node, which means it will soon be in a not-initialized state and will need to go through initialization, thus we need to set the node's initialization state to false *)
                       String.Map.set state.node_initialization
                         ~key:(Node.id node) ~data:false
                     in
                     let node_on' =
                       (* it should already be "on" but setting here just to be sure *)
                       String.Map.set state.node_on ~key:(Node.id node)
                         ~data:true
                     in
                     let best_tips_by_node' =
                       String.Map.remove state.best_tips_by_node (Node.id node)
                     in
                     { state with
                       node_initialization = node_initialization'
                     ; node_on = node_on'
                     ; best_tips_by_node = best_tips_by_node'
                     } )
               in
               let infra_id_before_refresh = Node.infra_id node in
               (* the pod_ids are refreshed in Node.start.  Node.infra_id references a mutable field *)
               let%bind (_
                          : ( unit Malleable_error.Result_accumulator.t
                            , Malleable_error.Hard_fail.t )
                            result ) =
                 Node.start ~fresh_state:false node
               in
               let infra_id_after_refresh = Node.infra_id node in

               (* if there was some kubernetes/infra failure that killed the pod for infra reasons, then the infra_id should be different.
                   In case of infra failure, lucy just wants to recover and keep chugging along.
                   But if the infra_id before and after the refresh is the same, then that means the node wasn't killed for infra reasons, in fact it means that the actual mina daemon crashed.  Actual daemon crashes SHOULD make a whole lucy test fail, lucy will throw a hard error and terminate rather than recovering *)
               if String.equal infra_id_after_refresh infra_id_before_refresh
               then
                 let%bind (_
                            : ( unit Malleable_error.Result_accumulator.t
                              , Malleable_error.Hard_fail.t )
                              result ) =
                   Malleable_error.or_hard_error ~exit_code:30
                     (Or_error.errorf
                        "The mina daemon of node %s has crashed.  The test will \
                         deliberately not recover and will now terminate."
                        (Node.id node) )
                 in
                 Deferred.return `Continue
               else
                 let%bind has_oom = Node.check_OOM_failure node in
                 if has_oom then
                   let%bind (_
                              : ( unit Malleable_error.Result_accumulator.t
                                , Malleable_error.Hard_fail.t )
                                result ) =
                     Malleable_error.or_hard_error ~exit_code:31
                       (Or_error.errorf
                          "The mina daemon of node %s has crashed because the \
                           daemon ran out of memory.  The test will \
                           deliberately not recover and will now terminate."
                          (Node.id node) )
                   in
                   Deferred.return `Continue
                 else Deferred.return `Continue *) )
        : _ Event_router.event_subscription ) ;
    (* handle_breadcrumb_added *)
    ignore
      ( Event_router.on event_router Event_type.Breadcrumb_added
          ~f:(fun node breadcrumb ->
            update ~f:(fun state ->
                [%log debug]
                  "Updating network state with Breadcrumb added to $node"
                  ~metadata:[ ("node", `String (Node.infra_id node)) ] ;
                let blocks_seen_by_node' =
                  String.Map.update state.blocks_seen_by_node (Node.id node)
                    ~f:(fun block_set ->
                      State_hash.Set.add
                        (Option.value block_set ~default:State_hash.Set.empty)
                        breadcrumb.state_hash )
                in
                let transaction_hashes =
                  List.map breadcrumb.transaction_hashes ~f:With_status.data
                in
                let blocks_including_txn' =
                  List.fold transaction_hashes ~init:state.blocks_including_txn
                    ~f:(fun accum hash ->
                      let block_set' =
                        State_hash.Set.add
                          ( Transaction_hash.Map.find accum hash
                          |> Option.value ~default:State_hash.Set.empty )
                          breadcrumb.state_hash
                      in
                      [%log debug]
                        "adding or updating txn_hash %s to \
                         state.blocks_including_txn"
                        (Transaction_hash.to_base58_check hash) ;
                      Transaction_hash.Map.set accum ~key:hash ~data:block_set' )
                in
                { state with
                  blocks_seen_by_node = blocks_seen_by_node'
                ; blocks_including_txn = blocks_including_txn'
                } ) )
        : _ Event_router.event_subscription ) ;
    (reader, writer)
end
