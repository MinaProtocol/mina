open Core_kernel
open Mina_base

(* TODO: abstract stackdriver specific log details *)

(* TODO: Monad_ext *)
let or_error_list_fold ls ~init ~f =
  let open Or_error.Let_syntax in
  List.fold ls ~init:(return init) ~f:(fun acc_or_error el ->
      let%bind acc = acc_or_error in
      f acc el )

let get_metadata (message : Logger.Message.t) key =
  match String.Map.find message.metadata key with
  | Some x ->
      Or_error.return x
  | None ->
      Or_error.errorf "did not find key \"%s\" in message metadata" key

let parse id (m : Logger.Message.t) =
  Or_error.try_with (fun () ->
      Structured_log_events.parse_exn id (Map.to_alist m.metadata) )

let bad_parse = Or_error.error_string "bad parse"

type 'a parse_event =
  | From_error_log of (Logger.Message.t -> 'a Or_error.t)
  | From_daemon_log of
      Structured_log_events.id * (Logger.Message.t -> 'a Or_error.t)
  | From_puppeteer_log of string * (Puppeteer_message.t -> 'a Or_error.t)

module type Event_type_intf = sig
  type t [@@deriving to_yojson]

  val name : string

  val parse : t parse_event
end

module Log_error = struct
  let name = "Log_error"

  type t = Logger.Message.t [@@deriving to_yojson]

  let parse_func = Or_error.return

  let parse = From_error_log parse_func
end

module Node_initialization = struct
  let name = "Node_initialization"

  type t = unit [@@deriving to_yojson]

  let structured_event_id =
    Transition_router
    .starting_transition_frontier_controller_structured_events_id

  let parse_func = Fn.const (Or_error.return ())

  let parse = From_daemon_log (structured_event_id, parse_func)
end

module Node_offline = struct
  let name = "Node_offline"

  type t = unit [@@deriving to_yojson]

  let puppeteer_event_type = "node_offline"

  let parse_func = Fn.const (Or_error.return ())

  let parse = From_puppeteer_log (puppeteer_event_type, parse_func)
end

module Transition_frontier_diff_application = struct
  let name = "Transition_frontier_diff_application"

  type root_transitioned =
    { new_root : State_hash.t; garbage : State_hash.t list }
  [@@deriving to_yojson]

  type t =
    { new_node : State_hash.t option
    ; best_tip_changed : State_hash.t option
    ; root_transitioned : root_transitioned option
    }
  [@@deriving lens, to_yojson]

  let empty =
    { new_node = None; best_tip_changed = None; root_transitioned = None }

  let register (lens : (t, 'a option) Lens.t) (result : t) (x : 'a) :
      t Or_error.t =
    match lens.get result with
    | Some _ ->
        Or_error.error_string
          "same transition frontier diff type unexpectedly encountered twice \
           in single application"
    | None ->
        Ok (lens.set (Some x) result)

  let structured_event_id =
    Transition_frontier.applying_diffs_structured_events_id

  let parse_func message =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%bind diffs = get_metadata message "diffs" >>= parse (list json) in
    or_error_list_fold diffs ~init:empty ~f:(fun res diff ->
        match Yojson.Safe.Util.keys diff with
        | [ name ] -> (
            let%bind value = find json diff [ name ] in
            match name with
            | "New_node" ->
                let%bind state_hash = parse state_hash value in
                register new_node res state_hash
            | "Best_tip_changed" ->
                let%bind state_hash = parse state_hash value in
                register best_tip_changed res state_hash
            | "Root_transitioned" ->
                let%bind new_root = find state_hash value [ "new_root" ] in
                let%bind garbage = find (list state_hash) value [ "garbage" ] in
                let data = { new_root; garbage } in
                register root_transitioned res data
            | _ ->
                Or_error.error_string "unexpected transition frontier diff name"
            )
        | _ ->
            Or_error.error_string "unexpected transition frontier diff format" )

  let parse = From_daemon_log (structured_event_id, parse_func)
end

module Block_produced = struct
  let name = "Block_produced"

  type t =
    { block_height : int
    ; epoch : int
    ; global_slot : int
    ; snarked_ledger_generated : bool
    ; state_hash : State_hash.t
    }
  [@@deriving to_yojson]

  (*
  let empty =
    {block_height= 0; epoch= 0; global_slot= 0; snarked_ledger_generated= false}

  (* Aggregated values for determining timeout conditions. Note: Slots passed and epochs passed are only determined if we produce a block. Add a log for these events to calculate these independently? *)
  type aggregated =
    {last_seen_result: t; blocks_generated: int; snarked_ledgers_generated: int}
  [@@deriving to_yojson]

  let empty_aggregated =
    {last_seen_result= empty; blocks_generated= 0; snarked_ledgers_generated= 0}

  let init_aggregated (result : t) =
    { last_seen_result= result
    ; blocks_generated= 1
    ; snarked_ledgers_generated=
        (if result.snarked_ledger_generated then 1 else 0) }

  (*Todo: Reorg will mess up the value of snarked_ledgers_generated*)
  let aggregate (aggregated : aggregated) (result : t) : aggregated =
    if result.block_height > aggregated.last_seen_result.block_height then
      { last_seen_result= result
      ; blocks_generated= aggregated.blocks_generated + 1
      ; snarked_ledgers_generated=
          ( if result.snarked_ledger_generated then
            aggregated.snarked_ledgers_generated + 1
          else aggregated.snarked_ledgers_generated ) }
    else aggregated
  *)

  let structured_event_id = Block_producer.block_produced_structured_events_id

  let parse_func message =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%bind breadcrumb = get_metadata message "breadcrumb" in
    let%bind state_hash_str =
      find string breadcrumb [ "validated_transition"; "hash"; "state_hash" ]
    in
    let%bind state_hash =
      State_hash.of_yojson (`String state_hash_str)
      |> fun res ->
      match res with
      | Ok hash ->
          Or_error.return hash
      | Error str ->
          Or_error.error_string str
    in
    let%bind snarked_ledger_generated =
      find bool breadcrumb [ "just_emitted_a_proof" ]
    in
    let%bind breadcrumb_consensus_state =
      find json breadcrumb
        [ "validated_transition"
        ; "data"
        ; "protocol_state"
        ; "body"
        ; "consensus_state"
        ]
    in
    let%bind block_height =
      find int breadcrumb_consensus_state [ "blockchain_length" ]
    in
    let%bind global_slot =
      find int breadcrumb_consensus_state [ "curr_global_slot"; "slot_number" ]
    in
    let%map epoch = find int breadcrumb_consensus_state [ "epoch_count" ] in
    { block_height; global_slot; epoch; snarked_ledger_generated; state_hash }

  let parse = From_daemon_log (structured_event_id, parse_func)
end

module Breadcrumb_added = struct
  let name = "Breadcrumb_added"

  type t =
    { state_hash : State_hash.t
    ; user_commands : User_command.Valid.t With_status.t list
    }
  [@@deriving to_yojson]

  let structured_event_id =
    Transition_frontier.added_breadcrumb_user_commands_structured_events_id

  let parse_func message =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%bind state_hash_json = get_metadata message "state_hash" in
    let state_hash =
      parser_from_of_yojson State_hash.of_yojson state_hash_json
    in
    let%map user_commands =
      get_metadata message "user_commands"
      >>= parse valid_commands_with_statuses
    in
    { state_hash; user_commands }

  let parse = From_daemon_log (structured_event_id, parse_func)
end

module Persisted_frontier_loaded = struct
  type t = unit [@@deriving to_yojson]

  let name = "persisted_frontier_loaded"

  let structured_event_id =
    Transition_frontier.persisted_frontier_loaded_structured_events_id

  let parse_func = Fn.const (Or_error.return ())

  let parse = From_daemon_log (structured_event_id, parse_func)
end

module Gossip = struct
  open Or_error.Let_syntax

  module Direction = struct
    type t = Sent | Received [@@deriving yojson]
  end

  module With_direction = struct
    type 'a t = 'a * Direction.t [@@deriving yojson]
  end

  module Block = struct
    type r = { state_hash : State_hash.t } [@@deriving yojson, hash]

    type t = r With_direction.t [@@deriving yojson]

    let name = "Block_gossip"

    let id = Transition_handler.Block_sink.block_received_structured_events_id

    let parse_func message =
      match%bind parse id message with
      | Transition_handler.Block_sink.Block_received { state_hash; sender = _ }
        ->
          Ok ({ state_hash }, Direction.Received)
      | Mina_networking.Gossip_new_state { state_hash } ->
          Ok ({ state_hash }, Sent)
      | _ ->
          bad_parse

    let parse = From_daemon_log (id, parse_func)
  end

  module Snark_work = struct
    type r = { work : Network_pool.Snark_pool.Resource_pool.Diff.compact }
    [@@deriving yojson, hash]

    type t = r With_direction.t [@@deriving yojson]

    let name = "Snark_work_gossip"

    let id =
      Network_pool.Snark_pool.Resource_pool.Diff
      .snark_work_received_structured_events_id

    let parse_func message =
      match%bind parse id message with
      | Network_pool.Snark_pool.Resource_pool.Diff.Snark_work_received
          { work; sender = _ } ->
          Ok ({ work }, Direction.Received)
      | Mina_networking.Gossip_snark_pool_diff { work } ->
          Ok ({ work }, Direction.Received)
      | _ ->
          bad_parse

    let parse = From_daemon_log (id, parse_func)
  end

  module Transactions = struct
    type r =
      { txns : Network_pool.Transaction_pool.Diff_versioned.Stable.Latest.t }
    [@@deriving yojson, hash]

    type t = r With_direction.t [@@deriving yojson]

    let name = "Transactions_gossip"

    let id =
      Network_pool.Transaction_pool.Resource_pool.Diff
      .transactions_received_structured_events_id

    let parse_func message =
      match%bind parse id message with
      | Network_pool.Transaction_pool.Resource_pool.Diff.Transactions_received
          { txns; sender = _ } ->
          Ok ({ txns }, Direction.Received)
      | Mina_networking.Gossip_transaction_pool_diff { txns } ->
          Ok ({ txns }, Sent)
      | _ ->
          bad_parse

    let parse = From_daemon_log (id, parse_func)
  end
end

module Snark_work_failed = struct
  type t = unit [@@deriving yojson]

  let name = "Transactions_gossip"

  let id = Snark_worker.generating_snark_work_failed_structured_events_id

  let parse_func message =
    let open Or_error.Let_syntax in
    match%bind parse id message with
    | Snark_worker.Generating_snark_work_failed ->
        Ok ()
    | _ ->
        bad_parse

  let parse = From_daemon_log (id, parse_func)
end

type 'a t =
  | Log_error : Log_error.t t
  | Node_initialization : Node_initialization.t t
  | Node_offline : Node_offline.t t
  | Transition_frontier_diff_application
      : Transition_frontier_diff_application.t t
  | Block_produced : Block_produced.t t
  | Breadcrumb_added : Breadcrumb_added.t t
  | Block_gossip : Gossip.Block.t t
  | Snark_work_gossip : Gossip.Snark_work.t t
  | Transactions_gossip : Gossip.Transactions.t t
  | Snark_work_failed : Snark_work_failed.t t
  | Persisted_frontier_loaded : Persisted_frontier_loaded.t t

type existential = Event_type : 'a t -> existential

let existential_to_string = function
  | Event_type Log_error ->
      "Log_error"
  | Event_type Node_initialization ->
      "Node_initialization"
  | Event_type Node_offline ->
      "Node_offline"
  | Event_type Transition_frontier_diff_application ->
      "Transition_frontier_diff_application"
  | Event_type Block_produced ->
      "Block_produced"
  | Event_type Breadcrumb_added ->
      "Breadcrumb_added"
  | Event_type Block_gossip ->
      "Block_gossip"
  | Event_type Snark_work_gossip ->
      "Snark_work_gossip"
  | Event_type Transactions_gossip ->
      "Transactions_gossip"
  | Event_type Snark_work_failed ->
      "Snark_work_failed"
  | Event_type Persisted_frontier_loaded ->
      "Persisted_frontier_loaded"

let to_string e = existential_to_string (Event_type e)

let existential_of_string_exn = function
  | "Log_error" ->
      Event_type Log_error
  | "Node_initialization" ->
      Event_type Node_initialization
  | "Node_offline" ->
      Event_type Node_offline
  | "Transition_frontier_diff_application" ->
      Event_type Transition_frontier_diff_application
  | "Block_produced" ->
      Event_type Block_produced
  | "Breadcrumb_added" ->
      Event_type Breadcrumb_added
  | "Block_gossip" ->
      Event_type Block_gossip
  | "Snark_work_gossip" ->
      Event_type Snark_work_gossip
  | "Transactions_gossip" ->
      Event_type Transactions_gossip
  | "Snark_work_failed" ->
      Event_type Snark_work_failed
  | "Persisted_frontier_loaded" ->
      Event_type Persisted_frontier_loaded
  | _ ->
      failwith "invalid event type string"

let existential_to_yojson t = `String (existential_to_string t)

let existential_of_sexp = function
  | Sexp.Atom string ->
      existential_of_string_exn string
  | _ ->
      failwith "invalid sexp"

let sexp_of_existential t = Sexp.Atom (existential_to_string t)

module Existentially_comparable = Comparable.Make (struct
  type t = existential [@@deriving sexp]

  (* We can't derive a comparison for the GADTs in ['a t], so fall back to
     polymorphic comparison. This should be safe to use here as the variants in
     ['a t] are shallow.
  *)
  let compare = Poly.compare
end)

module Map = Existentially_comparable.Map

type event = Event : 'a t * 'a -> event

let type_of_event (Event (t, _)) = Event_type t

(* needs to contain each type in event_types *)
let all_event_types =
  [ Event_type Log_error
  ; Event_type Node_initialization
  ; Event_type Node_offline
  ; Event_type Transition_frontier_diff_application
  ; Event_type Block_produced
  ; Event_type Breadcrumb_added
  ; Event_type Block_gossip
  ; Event_type Snark_work_gossip
  ; Event_type Transactions_gossip
  ; Event_type Snark_work_failed
  ; Event_type Persisted_frontier_loaded
  ]

let event_type_module : type a. a t -> (module Event_type_intf with type t = a)
    = function
  | Log_error ->
      (module Log_error)
  | Node_initialization ->
      (module Node_initialization)
  | Node_offline ->
      (module Node_offline)
  | Transition_frontier_diff_application ->
      (module Transition_frontier_diff_application)
  | Block_produced ->
      (module Block_produced)
  | Breadcrumb_added ->
      (module Breadcrumb_added)
  | Block_gossip ->
      (module Gossip.Block)
  | Snark_work_gossip ->
      (module Gossip.Snark_work)
  | Transactions_gossip ->
      (module Gossip.Transactions)
  | Snark_work_failed ->
      (module Snark_work_failed)
  | Persisted_frontier_loaded ->
      (module Persisted_frontier_loaded)

let event_to_yojson event =
  let (Event (t, d)) = event in
  let (module Type) = event_type_module t in
  `Assoc [ (to_string t, Type.to_yojson d) ]

let to_structured_event_id event_type =
  let (Event_type t) = event_type in
  let (module Ty) = event_type_module t in
  match Ty.parse with From_daemon_log (id, _) -> Some id | _ -> None

let structured_events_table =
  let open Option.Let_syntax in
  all_event_types
  |> List.filter_map ~f:(fun t ->
         let%map event_id = to_structured_event_id t in
         (Structured_log_events.string_of_id event_id, t) )
  |> String.Table.of_alist_exn

let of_structured_event_id id =
  Structured_log_events.string_of_id id
  |> String.Table.find structured_events_table

let to_puppeteer_event_string event_type =
  let (Event_type t) = event_type in
  let (module Ty) = event_type_module t in
  match Ty.parse with From_puppeteer_log (id, _) -> Some id | _ -> None

let puppeteer_events_table =
  let open Option.Let_syntax in
  all_event_types
  |> List.filter_map ~f:(fun t ->
         let%map event_id = to_puppeteer_event_string t in
         (event_id, t) )
  |> String.Table.of_alist_exn

let of_puppeteer_event_string id = String.Table.find puppeteer_events_table id

let parse_error_log (message : Logger.Message.t) =
  let open Or_error.Let_syntax in
  match Log_error.parse with
  | From_error_log fnc ->
      let%map data = fnc message in
      Event (Log_error, data)
  | _ ->
      failwith
        "Log_error.parse should always be a `From_error_log variant, but was \
         mis-programmed as something else. this is a progammer error"

let parse_daemon_event (message : Logger.Message.t) =
  let open Or_error.Let_syntax in
  match message.event_id with
  | Some event_id -> (
      let (Event_type ev_type) =
        of_structured_event_id event_id
        |> Option.value ~default:(Event_type Log_error)
      in
      let (module Ty) = event_type_module ev_type in
      match Ty.parse with
      | From_error_log fnc | From_daemon_log (_, fnc) ->
          let%map data = fnc message in
          Event (ev_type, data)
      | _ ->
          failwith
            "the 'parse' field of a daemon event should always be a \
             `From_daemon_log variant, but was mis-programmed as something \
             else. this is a progammer error" )
  | None ->
      (* TODO: check log level to ensure it matches error log level *)
      parse_error_log message

let parse_puppeteer_event (message : Puppeteer_message.t) =
  let open Or_error.Let_syntax in
  match
    Option.bind message.puppeteer_event_type ~f:of_puppeteer_event_string
  with
  | Some exis -> (
      let (Event_type ev_type) = exis in
      let (module Ty) = event_type_module ev_type in
      match Ty.parse with
      | From_puppeteer_log (_, fnc) ->
          let%map data = fnc message in
          Event (ev_type, data)
      | _ ->
          failwith
            "the 'parse' field of a puppeteer event should always be a \
             `From_puppeteer_log variant, but was mis-programmed as something \
             else. this is a progammer error" )
  | None ->
      failwith
        (Printf.sprintf
           "the events emitting from the puppeteer script are either not \
            formatted correctly, or are trying to emit an event_type which is \
            not actually recognized by the integration test framework.  this \
            should not happen and is a programmer error" )

let dispatch_exn : type a b c. a t -> a -> b t -> (b -> c) -> c =
 fun t1 e t2 h ->
  match (t1, t2) with
  | Log_error, Log_error ->
      h e
  | Node_initialization, Node_initialization ->
      h e
  | Node_offline, Node_offline ->
      h e
  | Transition_frontier_diff_application, Transition_frontier_diff_application
    ->
      h e
  | Block_produced, Block_produced ->
      h e
  | Breadcrumb_added, Breadcrumb_added ->
      h e
  | Block_gossip, Block_gossip ->
      h e
  | Transactions_gossip, Transactions_gossip ->
      h e
  | Snark_work_gossip, Snark_work_gossip ->
      h e
  | Persisted_frontier_loaded, Persisted_frontier_loaded ->
      h e
  | _ ->
      failwith "TODO: better error message :)"

(* TODO: tests on sexp and dispatch (etc) against all_event_types *)
