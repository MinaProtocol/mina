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

module type Event_type_intf = sig
  type t [@@deriving to_yojson]

  val name : string

  val structured_event_id : Structured_log_events.id option

  val parse : Logger.Message.t -> t Or_error.t
end

module Log_error = struct
  let name = "Log_error"

  let structured_event_id = None

  type t = Logger.Message.t [@@deriving to_yojson]

  let parse = Or_error.return
end

module Node_initialization = struct
  let name = "Node_initialization"

  let structured_event_id =
    Some
      Transition_router
      .starting_transition_frontier_controller_structured_events_id

  type t = unit [@@deriving to_yojson]

  let parse = Fn.const (Or_error.return ())
end

module Transition_frontier_diff_application = struct
  let name = "Transition_frontier_diff_application"

  let structured_event_id =
    Some Transition_frontier.applying_diffs_structured_events_id

  type root_transitioned = {new_root: State_hash.t; garbage: State_hash.t list}
  [@@deriving to_yojson]

  type t =
    { new_node: State_hash.t option
    ; best_tip_changed: State_hash.t option
    ; root_transitioned: root_transitioned option }
  [@@deriving lens, to_yojson]

  let empty = {new_node= None; best_tip_changed= None; root_transitioned= None}

  let register (lens : (t, 'a option) Lens.t) (result : t) (x : 'a) :
      t Or_error.t =
    match lens.get result with
    | Some _ ->
        Or_error.error_string
          "same transition frontier diff type unexpectedly encountered twice \
           in single application"
    | None ->
        Ok (lens.set (Some x) result)

  let parse message =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%bind diffs = get_metadata message "diffs" >>= parse (list json) in
    or_error_list_fold diffs ~init:empty ~f:(fun res diff ->
        match Yojson.Safe.Util.keys diff with
        | [name] -> (
            let%bind value = find json diff [name] in
            match name with
            | "New_node" ->
                let%bind state_hash = parse state_hash value in
                register new_node res state_hash
            | "Best_tip_changed" ->
                let%bind state_hash = parse state_hash value in
                register best_tip_changed res state_hash
            | "Root_transitioned" ->
                let%bind new_root = find state_hash value ["new_root"] in
                let%bind garbage = find (list state_hash) value ["garbage"] in
                let data = {new_root; garbage} in
                register root_transitioned res data
            | _ ->
                Or_error.error_string
                  "unexpected transition frontier diff name" )
        | _ ->
            Or_error.error_string "unexpected transition frontier diff format"
    )
end

module Block_produced = struct
  let name = "Block_produced"

  let structured_event_id =
    Some Block_producer.block_produced_structured_events_id

  type t =
    { block_height: int
    ; epoch: int
    ; global_slot: int
    ; snarked_ledger_generated: bool }
  [@@deriving to_yojson]

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

  (*TODO: Once we transition to structured events, this should call Structured_log_event.parse_exn and match on the structured events that it returns.*)
  let parse message =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%bind breadcrumb = get_metadata message "breadcrumb" in
    let%bind snarked_ledger_generated =
      find bool breadcrumb ["just_emitted_a_proof"]
    in
    let%bind breadcrumb_consensus_state =
      find json breadcrumb
        [ "validated_transition"
        ; "data"
        ; "protocol_state"
        ; "body"
        ; "consensus_state" ]
    in
    let%bind block_height =
      find int breadcrumb_consensus_state ["blockchain_length"]
    in
    let%bind global_slot =
      find int breadcrumb_consensus_state ["curr_global_slot"; "slot_number"]
    in
    let%map epoch = find int breadcrumb_consensus_state ["epoch_count"] in
    {block_height; global_slot; epoch; snarked_ledger_generated}
end

module Breadcrumb_added = struct
  let name = "Breadcrumb_added"

  let structured_event_id =
    Some
      Transition_frontier.added_breadcrumb_user_commands_structured_events_id

  type t = {user_commands: User_command.Valid.t With_status.t list}
  [@@deriving to_yojson]

  let parse message =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    let%map user_commands =
      get_metadata message "user_commands"
      >>= parse valid_commands_with_statuses
    in
    {user_commands}
end

type 'a t =
  | Log_error : Log_error.t t
  | Node_initialization : Node_initialization.t t
  | Transition_frontier_diff_application
      : Transition_frontier_diff_application.t t
  | Block_produced : Block_produced.t t
  | Breadcrumb_added : Breadcrumb_added.t t

type existential = Event_type : 'a t -> existential

let existential_to_string = function
  | Event_type Log_error ->
      "Log_error"
  | Event_type Node_initialization ->
      "Node_initialization"
  | Event_type Transition_frontier_diff_application ->
      "Transition_frontier_diff_application"
  | Event_type Block_produced ->
      "Block_produced"
  | Event_type Breadcrumb_added ->
      "Breadcrumb_added"

let existential_of_string_exn = function
  | "Log_error" ->
      Event_type Log_error
  | "Node_initialization" ->
      Event_type Node_initialization
  | "Transition_frontier_diff_application" ->
      Event_type Transition_frontier_diff_application
  | "Block_produced" ->
      Event_type Block_produced
  | "Breadcrumb_added" ->
      Event_type Breadcrumb_added
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

  (* polymorphic compare should be safe to use here as the variants in ['a t] are shallow *)
  let compare = Pervasives.compare
end)

module Map = Existentially_comparable.Map

type event = Event : 'a t * 'a -> event

let type_of_event (Event (t, _)) = Event_type t

(* needs to contain each type in event_types *)
let all_event_types =
  [ Event_type Log_error
  ; Event_type Node_initialization
  ; Event_type Transition_frontier_diff_application
  ; Event_type Block_produced
  ; Event_type Breadcrumb_added ]

let event_type_module : type a. a t -> (module Event_type_intf with type t = a)
    = function
  | Log_error ->
      (module Log_error)
  | Node_initialization ->
      (module Node_initialization)
  | Transition_frontier_diff_application ->
      (module Transition_frontier_diff_application)
  | Block_produced ->
      (module Block_produced)
  | Breadcrumb_added ->
      (module Breadcrumb_added)

let event_to_yojson event =
  let (Event (t, d)) = event in
  let (module Type) = event_type_module t in
  Type.to_yojson d

let to_structured_event_id event_type =
  let (Event_type t) = event_type in
  let (module Type) = event_type_module t in
  Type.structured_event_id

let of_structured_event_id =
  let open Option.Let_syntax in
  let table =
    all_event_types
    |> List.filter_map ~f:(fun t ->
           let%map event_id = to_structured_event_id t in
           (Structured_log_events.string_of_id event_id, t) )
    |> String.Table.of_alist_exn
  in
  Fn.compose (String.Table.find table) Structured_log_events.string_of_id

let parse_event (message : Logger.Message.t) =
  let open Or_error.Let_syntax in
  match message.event_id with
  | Some event_id ->
      let (Event_type event_type) =
        of_structured_event_id event_id
        |> Option.value_exn
             ~message:
               "could not convert incoming event log into event type; no \
                matching structured event id"
      in
      let (module Type) = event_type_module event_type in
      let%map data = Type.parse message in
      Event (event_type, data)
  | None ->
      (* TODO: check log level to ensure it matches error log level *)
      let%map data = Log_error.parse message in
      Event (Log_error, data)

let dispatch_exn : type a b c. a t -> a -> b t -> (b -> c) -> c =
 fun t1 e t2 h ->
  match (t1, t2) with
  | Log_error, Log_error ->
      h e
  | Node_initialization, Node_initialization ->
      h e
  | Transition_frontier_diff_application, Transition_frontier_diff_application
    ->
      h e
  | Block_produced, Block_produced ->
      h e
  | Breadcrumb_added, Breadcrumb_added ->
      h e
  | _ ->
      failwith "TODO: better error message :)"

(* TODO: tests on sexp and dispatch (etc) against all_event_types *)
