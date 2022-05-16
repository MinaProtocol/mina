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

  type t =
    { description : string
    ; predicate : predicate
    ; soft_timeout : Network_time_span.t
    ; hard_timeout : Network_time_span.t
    }

  let with_timeouts ?soft_timeout ?hard_timeout t =
    { t with
      soft_timeout = Option.value soft_timeout ~default:t.soft_timeout
    ; hard_timeout = Option.value hard_timeout ~default:t.hard_timeout
    }

  let network_state ~description ~(f : Network_state.t -> bool) : t =
    let check () (state : Network_state.t) =
      if f state then Predicate_passed else Predicate_continuation ()
    in
    { description
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Literal (Time.Span.of_hr 1.0)
    ; hard_timeout = Literal (Time.Span.of_hr 2.0)
    }

  let nodes_to_initialize nodes =
    let open Network_state in
    network_state
      ~description:
        ( nodes |> List.map ~f:Node.id |> String.concat ~sep:", "
        |> Printf.sprintf "[%s] to initialize" )
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
    { description = Printf.sprintf "%d blocks to be produced" n
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
    { description = Printf.sprintf "%s to synchronize" formatted_nodes
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
    { description =
        Printf.sprintf "signed command with hash %s"
          (Transaction_hash.to_base58_check txn_hash)
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let ledger_proofs_emitted_since_genesis ~num_proofs =
    let open Network_state in
    let check () (state : Network_state.t) =
      if state.snarked_ledgers_generated >= num_proofs then Predicate_passed
      else Predicate_continuation ()
    in
    let description =
      Printf.sprintf "[%d] snarked_ledgers to be generated since genesis"
        num_proofs
    in
    { description
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Slots 15
    ; hard_timeout = Slots 20
    }

  let snapp_to_be_included_in_frontier ~has_failures ~parties =
    let command_matches_parties cmd =
      let open User_command in
      match cmd with
      | Parties p ->
          Parties.equal p parties
      | Signed_command _ ->
          false
    in
    let check () _node (breadcrumb_added : Event_type.Breadcrumb_added.t) =
      let snapp_opt =
        List.find breadcrumb_added.user_commands ~f:(fun cmd_with_status ->
            cmd_with_status.With_status.data |> User_command.forget_check
            |> command_matches_parties )
      in
      match snapp_opt with
      | Some cmd_with_status ->
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
    { description =
        sprintf "snapp with fee payer %s and other parties (%s)"
          (Signature_lib.Public_key.Compressed.to_base58_check
             parties.fee_payer.body.public_key )
          (Parties.Call_forest.Tree.fold_forest ~init:"" parties.other_parties
             ~f:(fun acc party ->
               let str =
                 Signature_lib.Public_key.Compressed.to_base58_check
                   party.body.public_key
               in
               if !is_first then (
                 is_first := false ;
                 str )
               else acc ^ ", " ^ str ) )
    ; predicate = Event_predicate (Event_type.Breadcrumb_added, (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }
end
