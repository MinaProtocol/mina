open Core_kernel
open Mina_base
open Mina_transaction

let all_equal ~equal ~compare ls =
  Option.value_map (List.hd ls) ~default:true ~f:(fun h ->
      List.equal equal [ h ] (List.find_all_dups ~compare ls) )

module Make
    (Engine : Intf.Engine.S)
    (Event_router : Intf.Dsl.Event_router_intf with module Engine := Engine)
    (Network_state : Intf.Dsl.Network_state_intf
                       with module Engine := Engine
                        and module Event_router := Event_router) =
struct
  open Network_state
  module Node = Engine.Network.Node

  type 'a predicate_result =
    | Predicate_passed
    | Predicate_continuation of 'a
    | Predicate_failure of Error.t

  (* NEED TO LIFT THIS UP OR FUNCTOR IT *)
  type predicate =
    | Network_state_predicate :
        (Network_state.t -> 'a predicate_result)
        * ('a -> Network_state.t -> 'a predicate_result)
        -> predicate
    | Event_predicate :
        'b Event_type.t * 'a * ('a -> Node.t -> 'b -> 'a predicate_result)
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
    | Transition_frontier_loaded_from_persistence

  type t =
    { id : wait_condition_id
    ; description : string
    ; predicate : predicate
    ; soft_timeout : Network_time_span.t
    ; hard_timeout : Network_time_span.t
    }

  let with_timeouts ?soft_timeout ?hard_timeout t =
    { t with
      soft_timeout = Option.value soft_timeout ~default:t.soft_timeout
    ; hard_timeout = Option.value hard_timeout ~default:t.hard_timeout
    }

  let network_state ~id ~description ~(f : Network_state.t -> bool) : t =
    let check () (state : Network_state.t) =
      if f state then Predicate_passed else Predicate_continuation ()
    in
    { id
    ; description
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Literal (Time.Span.of_hr 1.0)
    ; hard_timeout = Literal (Time.Span.of_hr 2.0)
    }

  let wait_condition_id t = t.id

  let nodes_to_initialize nodes =
    let open Network_state in
    network_state ~id:Nodes_to_initialize
      ~description:
        ( nodes |> List.map ~f:Node.id |> String.concat ~sep:", "
        |> sprintf "[%s] to initialize" )
      ~f:(fun (state : Network_state.t) ->
        List.for_all nodes ~f:(fun node ->
            String.Map.find state.node_initialization (Node.id node)
            |> Option.value ~default:false ) )
    |> with_timeouts
         ~soft_timeout:(Literal (Time.Span.of_min 10.0))
         ~hard_timeout:(Literal (Time.Span.of_min 15.0))

  let node_to_initialize node = nodes_to_initialize [ node ]

  (* let blocks_produced ?(active_stake_percentage = 1.0) n = *)
  let blocks_to_be_produced n =
    let init state = Predicate_continuation state.blocks_generated in
    let check init_blocks_generated state =
      if state.blocks_generated - init_blocks_generated >= n then
        Predicate_passed
      else Predicate_continuation init_blocks_generated
    in
    let soft_timeout_in_slots =
      (* We add 1 here to make sure that we see the entirety of at least 2*n
         full slots, since slot time may be misaligned with wait times after
         non-block-related waits.
         This ensures that low numbers of blocks (e.g. 1 or 2) have a
         reasonable probability of success, reducing flakiness of the tests.
      *)
      (2 * n) + 1
    in
    { id = Blocks_to_be_produced
    ; description = sprintf "%d blocks to be produced" n
    ; predicate = Network_state_predicate (init, check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let transition_frontier_loaded_from_persistence ~fresh_data ~sync_needed =
    let init state =
      Predicate_continuation
        ( state.num_persisted_frontier_loaded
        , state.num_persisted_frontier_fresh_boot
        , state.num_bootstrap_required
        , state.num_persisted_frontier_dropped
        , state.num_transition_frontier_loaded_from_persistence )
    in

    let check init state =
      let ( num_init_persisted_frontier_loaded
          , num_init_persisted_frontier_fresh_boot
          , num_init_bootstrap_required
          , num_init_persisted_frontier_dropped
          , num_init_transition_frontier_loaded_from_persistence ) =
        init
      in

      let fresh_data_condition =
        if fresh_data then
          state.num_persisted_frontier_fresh_boot
          > num_init_persisted_frontier_fresh_boot
          && state.num_persisted_frontier_dropped
             > num_init_persisted_frontier_dropped
        else
          state.num_persisted_frontier_fresh_boot
          = num_init_persisted_frontier_fresh_boot
          && state.num_persisted_frontier_dropped
             = num_init_persisted_frontier_dropped
      in
      let sync_needed_condition =
        if sync_needed then
          state.num_bootstrap_required >= num_init_bootstrap_required
        else state.num_bootstrap_required = num_init_bootstrap_required
      in
      if
        fresh_data_condition && sync_needed_condition
        && state.num_persisted_frontier_loaded
           > num_init_persisted_frontier_loaded
        && state.num_transition_frontier_loaded_from_persistence
           > num_init_transition_frontier_loaded_from_persistence
      then Predicate_passed
      else
        Predicate_continuation
          ( num_init_persisted_frontier_loaded
          , num_init_persisted_frontier_fresh_boot
          , num_init_bootstrap_required
          , num_init_persisted_frontier_dropped
          , num_init_transition_frontier_loaded_from_persistence )
    in
    { id = Transition_frontier_loaded_from_persistence
    ; description =
        sprintf
          "Transition frontier loaded with 'fresh_data' set to %b and \
           'sync_needed' set to %b"
          fresh_data sync_needed
    ; predicate = Network_state_predicate (init, check)
    ; soft_timeout = Literal (Time.Span.of_min 10.0)
    ; hard_timeout = Literal (Time.Span.of_min 15.0)
    }

  let block_height_growth ~height_growth =
    (* block height is an objective measurement for the whole chain.  block height growth checks that the block height increased by the desired_height since the wait condition was called *)
    let init state = Predicate_continuation state.block_height in
    let check initial_height (state : Network_state.t) =
      if state.block_height - initial_height >= height_growth then
        Predicate_passed
      else Predicate_continuation initial_height
    in
    let description =
      sprintf "chain block height greater than equal to [%d] " height_growth
    in
    let soft_timeout_in_slots = (2 * height_growth) + 1 in
    { id = Block_height_growth
    ; description
    ; predicate = Network_state_predicate (init, check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let nodes_to_synchronize (nodes : Node.t list) =
    let check () state =
      let all_best_tips_equal =
        all_equal ~equal:[%equal: State_hash.t option]
          ~compare:[%compare: State_hash.t option]
      in
      let best_tips =
        List.map nodes ~f:(fun node ->
            String.Map.find state.best_tips_by_node (Node.id node) )
      in
      if
        List.for_all best_tips ~f:Option.is_some
        && all_best_tips_equal best_tips
      then Predicate_passed
      else Predicate_continuation ()
    in
    let soft_timeout_in_slots = 8 * 3 in
    let formatted_nodes =
      nodes
      |> List.map ~f:(fun node -> "\"" ^ Node.id node ^ "\"")
      |> String.concat ~sep:", "
    in
    { id = Nodes_to_synchronize
    ; description = sprintf "%s to synchronize" formatted_nodes
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let signed_command_to_be_included_in_frontier ~txn_hash
      ~(node_included_in : [ `Any_node | `Node of Node.t ]) =
    let check () state =
      let blocks_with_txn_set_opt =
        Map.find state.blocks_including_txn txn_hash
      in
      match blocks_with_txn_set_opt with
      | None ->
          Predicate_continuation ()
      | Some blocks_with_txn_set -> (
          match node_included_in with
          | `Any_node ->
              Predicate_passed
          | `Node n ->
              let blocks_seen_by_n =
                Map.find state.blocks_seen_by_node (Node.id n)
                |> Option.value ~default:State_hash.Set.empty
              in
              let intersection =
                State_hash.Set.inter blocks_with_txn_set blocks_seen_by_n
              in
              if State_hash.Set.is_empty intersection then
                Predicate_continuation ()
              else Predicate_passed )
    in

    let soft_timeout_in_slots = 8 in
    { id = Signed_command_to_be_included_in_frontier
    ; description =
        sprintf "signed command with hash %s"
          (Transaction_hash.to_base58_check txn_hash)
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let ledger_proofs_emitted_since_genesis ~test_config ~num_proofs =
    let open Network_state in
    let check () (state : Network_state.t) =
      if state.snarked_ledgers_generated >= num_proofs then Predicate_passed
      else Predicate_continuation ()
    in
    let description =
      sprintf "[%d] snarked_ledgers to be generated since genesis" num_proofs
    in
    let slots_for_first_proof =
      Test_config.(
        slots_for_blocks @@ blocks_for_first_ledger_proof test_config)
    in
    let slots_for_additional_proofs =
      Test_config.slots_for_blocks (num_proofs - 1)
    in
    let total_slots = slots_for_first_proof + slots_for_additional_proofs in
    { id = Ledger_proofs_emitted_since_genesis
    ; description
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Network_time_span.Slots (total_slots + 6)
    ; hard_timeout = Network_time_span.Slots (total_slots + 12)
    }

  let zkapp_to_be_included_in_frontier ~has_failures ~zkapp_command =
    let command_matches_zkapp_command cmd =
      let open User_command in
      match cmd with
      | Zkapp_command p ->
          Zkapp_command.equal p zkapp_command
      | Signed_command _ ->
          false
    in
    let check () _node (breadcrumb_added : Event_type.Breadcrumb_added.t) =
      let zkapp_opt =
        List.find breadcrumb_added.user_commands ~f:(fun cmd_with_status ->
            cmd_with_status.With_status.data |> User_command.forget_check
            |> command_matches_zkapp_command )
      in
      [%log' info (Logger.create ())]
        "Looking for a zkApp transaction match in block with state_hash \
         $state_hash"
        ~metadata:
          [ ("state_hash", State_hash.to_yojson breadcrumb_added.state_hash) ] ;
      [%log' debug (Logger.create ())]
        "wait_condition check, zkapp_to_be_included_in_frontier, \
         zkapp_command: $zkapp_command "
        ~metadata:[ ("zkapp_command", Zkapp_command.to_yojson zkapp_command) ] ;
      [%log' debug (Logger.create ())]
        "wait_condition check, zkapp_to_be_included_in_frontier, user_commands \
         from breadcrumb: $user_commands state_hash: $state_hash"
        ~metadata:
          [ ( "user_commands"
            , `List
                (List.map breadcrumb_added.user_commands
                   ~f:(With_status.to_yojson User_command.Valid.to_yojson) ) )
          ; ("state_hash", State_hash.to_yojson breadcrumb_added.state_hash)
          ] ;
      match zkapp_opt with
      | Some cmd_with_status ->
          [%log' debug (Logger.create ())]
            "wait_condition check, zkapp_to_be_included_in_frontier, \
             cmd_with_status: $cmd_with_status "
            ~metadata:
              [ ( "cmd_with_status"
                , (With_status.to_yojson User_command.Valid.to_yojson)
                    cmd_with_status )
              ] ;
          let actual_status = cmd_with_status.With_status.status in
          let successful =
            match actual_status with
            | Transaction_status.Applied ->
                not has_failures
            | Failed _ ->
                has_failures
          in
          if successful then Predicate_passed
          else
            Predicate_failure
              (Error.createf "Unexpected status in matching payment: %s"
                 ( Transaction_status.to_yojson actual_status
                 |> Yojson.Safe.to_string ) )
      | None ->
          Predicate_continuation ()
    in
    let soft_timeout_in_slots = 8 in
    let is_first = ref true in
    { id = Zkapp_to_be_included_in_frontier
    ; description =
        sprintf "zkApp with fee payer %s and other zkapp_command (%s), memo: %s"
          (Signature_lib.Public_key.Compressed.to_base58_check
             zkapp_command.fee_payer.body.public_key )
          (Zkapp_command.Call_forest.Tree.fold_forest ~init:""
             zkapp_command.account_updates ~f:(fun acc account_update ->
               let str =
                 Signature_lib.Public_key.Compressed.to_base58_check
                   account_update.body.public_key
               in
               if !is_first then (
                 is_first := false ;
                 str )
               else acc ^ ", " ^ str ) )
          (Signed_command_memo.to_string_hum zkapp_command.memo)
    ; predicate = Event_predicate (Event_type.Breadcrumb_added, (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let persisted_frontier_loaded node =
    let check () event_node
        (_frontier_loaded : Event_type.Persisted_frontier_loaded.t) =
      let event_node_id = Node.id event_node in
      let node_id = Node.id node in
      if String.equal event_node_id node_id then Predicate_passed
      else Predicate_continuation ()
    in
    let soft_timeout_in_slots = 4 in
    { id = Persisted_frontier_loaded
    ; description = "persisted transition frontier to load"
    ; predicate =
        Event_predicate (Event_type.Persisted_frontier_loaded, (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }
end
