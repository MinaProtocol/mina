open Core_kernel
open Mina_base
open Currency
open Signature_lib

let all_equal ~equal ~compare ls =
  Option.value_map (List.hd ls) ~default:true ~f:(fun h ->
      List.equal equal [ h ] (List.find_all_dups ~compare ls))

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

  let nodes_to_initialize nodes =
    let open Network_state in
    let check () (state : Network_state.t) =
      if
        List.for_all nodes ~f:(fun node ->
            String.Map.find state.node_initialization (Node.id node)
            |> Option.value ~default:false)
      then Predicate_passed
      else Predicate_continuation ()
    in
    let description =
      nodes |> List.map ~f:Node.id |> String.concat ~sep:", "
      |> Printf.sprintf "[%s] to initialize"
    in
    { description
    ; predicate = Network_state_predicate (check (), check)
    ; soft_timeout = Literal (Time.Span.of_min 10.0)
    ; hard_timeout = Literal (Time.Span.of_min 15.0)
    }

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
            String.Map.find state.best_tips_by_node (Node.id node))
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

  type command_type = Send_payment | Send_delegation

  let command_type_to_string command_type =
    match command_type with
    | Send_payment ->
        "Send Payment"
    | Send_delegation ->
        "Send Delegation"

  let signed_command_to_be_included_in_frontier ~sender_pub_key
      ~receiver_pub_key ~amount ~(nonce : Mina_numbers.Account_nonce.t)
      ~command_type =
    let command_matches_payment cmd =
      let open User_command in
      match cmd with
      | Signed_command signed_cmd -> (
          let open Signature_lib in
          let payload = Signed_command.payload signed_cmd in
          let body = payload |> Signed_command_payload.body in
          match body with
          | Payment { source_pk; receiver_pk; amount = paid_amt; token_id = _ }
            when Public_key.Compressed.equal source_pk sender_pub_key
                 && Public_key.Compressed.equal receiver_pk receiver_pub_key
                 && Currency.Amount.equal paid_amt amount
                 && Mina_numbers.Account_nonce.equal nonce
                      (Signed_command_payload.nonce payload) -> (
              match command_type with Send_payment -> true | _ -> false )
          | Stake_delegation dl -> (
              match dl with
              | Set_delegate
                  { delegator : Public_key.Compressed.t
                  ; new_delegate : Public_key.Compressed.t
                  }
                when Public_key.Compressed.equal delegator sender_pub_key
                     && Public_key.Compressed.equal new_delegate
                          receiver_pub_key -> (
                  match command_type with Send_delegation -> true | _ -> false )
              | _ ->
                  false )
          | _ ->
              false )
      | Parties _ ->
          false
    in
    let check () _node (breadcrumb_added : Event_type.Breadcrumb_added.t) =
      let payment_opt =
        List.find breadcrumb_added.user_commands ~f:(fun cmd_with_status ->
            cmd_with_status.With_status.data |> User_command.forget_check
            |> command_matches_payment)
      in
      match payment_opt with
      | Some cmd_with_status ->
          let actual_status = cmd_with_status.With_status.status in
          let was_applied =
            match actual_status with
            | Transaction_status.Applied _ ->
                true
            | _ ->
                false
          in
          if was_applied then Predicate_passed
          else
            Predicate_failure
              (Error.createf "Unexpected status in matching payment: %s"
                 ( Transaction_status.to_yojson actual_status
                 |> Yojson.Safe.to_string ))
      | None ->
          Predicate_continuation ()
    in
    let soft_timeout_in_slots = 8 in
    { description =
        Printf.sprintf "signed command of type %s from %s to %s of amount %s"
          (command_type_to_string command_type)
          (Public_key.Compressed.to_string sender_pub_key)
          (Public_key.Compressed.to_string receiver_pub_key)
          (Amount.to_string amount)
    ; predicate = Event_predicate (Event_type.Breadcrumb_added, (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }

  let snapp_to_be_included_in_frontier ~parties =
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
            |> command_matches_parties)
      in
      match snapp_opt with
      | Some cmd_with_status ->
          let actual_status = cmd_with_status.With_status.status in
          let was_applied =
            match actual_status with
            | Transaction_status.Applied _ ->
                true
            | _ ->
                false
          in
          if was_applied then Predicate_passed
          else
            Predicate_failure
              (Error.createf "Unexpected status in matching payment: %s"
                 ( Transaction_status.to_yojson actual_status
                 |> Yojson.Safe.to_string ))
      | None ->
          Predicate_continuation ()
    in
    let soft_timeout_in_slots = 8 in
    { description =
        sprintf "snapp with fee payer %s and other parties (%s)"
          (Public_key.Compressed.to_base58_check
             parties.fee_payer.data.body.public_key)
          ( List.map parties.other_parties ~f:(fun party ->
                Public_key.Compressed.to_base58_check party.data.body.public_key)
          |> String.concat ~sep:", " )
    ; predicate = Event_predicate (Event_type.Breadcrumb_added, (), check)
    ; soft_timeout = Slots soft_timeout_in_slots
    ; hard_timeout = Slots (soft_timeout_in_slots * 2)
    }
end
