open Async
open Core
open Pipe_lib
open Mina_base
open Integration_test_lib
module Timeout = Timeout_lib.Core_time

(** This implements Log_engine_intf for stack driver logs for integration tests
    Assumptions:
      1. gcloud is installed and authorized to perform logging and pubsub related changes
      2. gcloud API key is set in the environment variable GCLOUD_API_KEY*)

(*Project Id is required for creating topic, sinks, and subscriptions*)
let project_id = "o1labs-192920"

let prog = "gcloud"

let yojson_from_string json_str =
  Or_error.try_with (fun () -> Yojson.Safe.from_string json_str)

let or_error_list_fold ls ~init ~f =
  let open Or_error.Let_syntax in
  List.fold ls ~init:(return init) ~f:(fun acc_or_error el ->
      let%bind acc = acc_or_error in
      f acc el )

let or_error_list_map ls ~f =
  let open Or_error.Let_syntax in
  or_error_list_fold ls ~init:[] ~f:(fun t el ->
      let%map h = f el in
      h :: t )

module Subscription = struct
  type t = {name: string; topic: string; sink: string}

  (*Using the api endpoint to create a sink instead of the gcloud command
  because the cli doesn't allow setting the writerIdentity account for the sink
  and instead generates an account that doesn't have permissions to publish
  logs to the topic. The account needs to be given permissions explicitly and
  then there's this from the documentation:
    There is a delay between creating the sink and using the sink's new service
     account to authorize writing to the export destination. During the first 24
     hours after sink creation, you might see permission-related error messages
     from the sink on your project's Activity page; you can ignore them.
  *)
  let create_sink ~topic ~filter ~key ~logger name =
    let open Deferred.Or_error.Let_syntax in
    let url =
      "https://logging.googleapis.com/v2/projects/o1labs-192920/sinks?key="
      ^ key
    in
    let%bind authorization =
      let%map token =
        Process.run ~prog ~args:["auth"; "print-access-token"] ()
      in
      let token = String.strip token in
      String.concat ["Authorization: Bearer "; token]
    in
    let req_type = "Accept: application/json" in
    let content_type = "Content-Type: application/json" in
    let destination =
      String.concat ~sep:"/"
        ["pubsub.googleapis.com"; "projects"; project_id; "topics"; topic]
    in
    let header = "--header" in
    let data =
      `Assoc
        [ ("name", `String name)
        ; ("description", `String "Sink for tests")
        ; ("destination", `String destination)
        ; ("filter", `String filter) ]
      |> Yojson.Safe.to_string
    in
    let%bind response =
      Process.run ~prog:"curl"
        ~args:
          [ "--request"
          ; "POST"
          ; url
          ; header
          ; authorization
          ; header
          ; req_type
          ; header
          ; content_type
          ; "--data"
          ; data
          ; "--compressed" ]
        ()
    in
    let%bind response_json = Deferred.return (yojson_from_string response) in
    [%log debug] "Create sink response: $response"
      ~metadata:[("response", response_json)] ;
    match
      Yojson.Safe.Util.(to_option Fn.id (member "error" response_json))
    with
    | Some _ ->
        Deferred.Or_error.errorf "Error when creating sink: %s" response
    | None ->
        Deferred.Or_error.ok_unit

  let create ~name ~filter ~logger =
    let open Deferred.Or_error.Let_syntax in
    let uuid = Uuid_unix.create () in
    let name = name ^ "_" ^ Uuid.to_string uuid in
    let gcloud_key_file_env = "GCLOUD_API_KEY" in
    let%bind key =
      match Sys.getenv gcloud_key_file_env with
      | Some key ->
          return key
      | None ->
          Deferred.Or_error.errorf
            "Set environment variable %s with the service account key to use \
             Stackdriver logging"
            gcloud_key_file_env
    in
    let create_topic name =
      Process.run ~prog ~args:["pubsub"; "topics"; "create"; name] ()
    in
    let create_subscription name topic =
      Process.run ~prog
        ~args:
          [ "pubsub"
          ; "subscriptions"
          ; "create"
          ; name
          ; "--topic"
          ; topic
          ; "--topic-project"
          ; project_id ]
        ()
    in
    let topic = name ^ "_topic" in
    let sink = name ^ "_sink" in
    let%bind _ = create_topic topic in
    let%bind _ = create_sink ~topic ~filter ~key ~logger sink in
    let%map _ = create_subscription name topic in
    {name; topic; sink}

  let delete t =
    let open Deferred.Or_error.Let_syntax in
    let delete_subscription =
      Process.run ~prog
        ~args:
          ["pubsub"; "subscriptions"; "delete"; t.name; "--project"; project_id]
        ()
    in
    let delete_sink =
      Process.run ~prog
        ~args:["logging"; "sinks"; "delete"; t.sink; "--project"; project_id]
        ()
    in
    let delete_topic =
      Process.run ~prog
        ~args:["pubsub"; "topics"; "delete"; t.topic; "--project"; project_id]
        ()
    in
    let%map _ =
      Deferred.Or_error.combine_errors
        [delete_subscription; delete_sink; delete_topic]
    in
    ()

  let pull t =
    let open Deferred.Or_error.Let_syntax in
    let subscription_id =
      String.concat ~sep:"/" ["projects"; project_id; "subscriptions"; t.name]
    in
    (* The limit for messages we pull on each interval is currently not configurable. For now, it's set to 5 (which will hopefully be a sane for a while). *)
    let%bind result =
      Process.run ~prog
        ~args:
          [ "pubsub"
          ; "subscriptions"
          ; "pull"
          ; subscription_id
          ; "--auto-ack"
          ; "--limit"
          ; string_of_int 5
          ; "--format"
          ; "table(DATA)" ]
        ()
    in
    match String.split_lines result with
    | [] | ["DATA"] ->
        return []
    | "DATA" :: data ->
        Deferred.return (or_error_list_map data ~f:yojson_from_string)
    | _ ->
        Deferred.Or_error.errorf "Invalid subscription pull result: %s" result
end

module Json_parsing = struct
  open Yojson.Safe.Util

  type 'a parser = Yojson.Safe.t -> 'a

  let json : Yojson.Safe.t parser = Fn.id

  let bool : bool parser = to_bool

  let string : string parser = to_string

  let int : int parser =
   fun x -> try to_int x with Type_error _ -> int_of_string (to_string x)

  let float : float parser =
   fun x -> try to_float x with Type_error _ -> float_of_string (to_string x)

  let list : 'a parser -> 'a list parser = fun f x -> List.map ~f (to_list x)

  let state_hash : State_hash.t parser =
    Fn.compose Result.ok_or_failwith State_hash.of_yojson

  let parse (parser : 'a parser) (json : Yojson.Safe.t) : 'a Or_error.t =
    try Ok (parser json)
    with exn ->
      Or_error.errorf "failed to parse json value: %s" (Exn.to_string exn)

  let parser_from_of_yojson of_yojson js =
    match of_yojson js with
    | Ok cmd ->
        cmd
    | Error modl ->
        let logger = Logger.create () in
        [%log error] "Could not parse JSON using of_yojson"
          ~metadata:[("module", `String modl); ("json", js)] ;
        failwithf "Could not parse JSON using %s.of_yojson" modl ()

  let valid_commands_with_statuses :
      Mina_base.User_command.Valid.t Mina_base.With_status.t list parser =
    function
    | `List cmds ->
        let cmd_or_errors =
          List.map cmds
            ~f:
              (Mina_base.With_status.of_yojson
                 Mina_base.User_command.Valid.of_yojson)
        in
        List.fold cmd_or_errors ~init:[] ~f:(fun accum cmd_or_err ->
            match (accum, cmd_or_err) with
            | _, Error err ->
                let logger = Logger.create () in
                [%log error]
                  ~metadata:[("error", `String err)]
                  "Failed to parse JSON for user command status" ;
                (* fail on any error *)
                failwith
                  "valid_commands_with_statuses: unable to parse JSON for \
                   user command"
            | cmds, Ok cmd ->
                cmd :: cmds )
    | _ ->
        failwith "valid_commands_with_statuses: expected `List"

  let rec find (parser : 'a parser) (json : Yojson.Safe.t) (path : string list)
      : 'a Or_error.t =
    let open Or_error.Let_syntax in
    match (path, json) with
    | [], _ ->
        parse parser json
    | key :: path', `Assoc assoc ->
        let%bind entry =
          match List.Assoc.find assoc key ~equal:String.equal with
          | Some entry ->
              Ok entry
          | None ->
              Or_error.errorf
                "failed to find path using key '%s' in json object { %s }" key
                (String.concat ~sep:", "
                   (List.map assoc ~f:(fun (s, json) ->
                        sprintf "\"%s\":%s" s (Yojson.Safe.to_string json) )))
        in
        find parser entry path'
    | _ ->
        Or_error.error_string "expected json object when searching for path"
end

module Event_type = struct
  module type Event_type_intf = sig
    type t [@@deriving to_yojson]

    val name : string

    val structured_event_id : Structured_log_events.id option

    val parse : Yojson.Safe.t -> t Or_error.t
  end

  module Log_error = struct
    let name = "Log_error"

    let structured_event_id = None

    type t = {pod_id: string; message: Logger.Message.t} [@@deriving to_yojson]

    let parse log =
      let open Json_parsing in
      let open Or_error.Let_syntax in
      let%bind pod_id = find string log ["labels"; "k8s-pod/app"] in
      let%bind payload = find json log ["jsonPayload"] in
      let%map message =
        parse (parser_from_of_yojson Logger.Message.of_yojson) payload
      in
      {pod_id; message}
  end

  module Node_initialization = struct
    let name = "Node_initialization"

    let structured_event_id =
      Some
        Transition_router
        .starting_transition_frontier_controller_structured_events_id

    type t = {pod_id: string} [@@deriving to_yojson]

    let parse log =
      let open Json_parsing in
      let open Or_error.Let_syntax in
      let%map pod_id = find string log ["labels"; "k8s-pod/app"] in
      {pod_id}
  end

  module Breadcrumb_added = struct
    let name = "Breadcrumb_added"

    let structured_event_id =
      Some
        Transition_frontier.added_breadcrumb_user_commands_structured_events_id

    type t = {user_commands: User_command.Valid.t With_status.t list}
    [@@deriving to_yojson]

    let parse log =
      let open Json_parsing in
      let open Or_error.Let_syntax in
      let path = ["jsonPayload"; "metadata"; "user_commands"] in
      let%map user_commands = find valid_commands_with_statuses log path in
      {user_commands}
  end

  module Transition_frontier_diff_application = struct
    let name = "Transition_frontier_diff_application"

    let structured_event_id =
      Some Transition_frontier.applying_diffs_structured_events_id

    type root_transitioned =
      {new_root: State_hash.t; garbage: State_hash.t list}
    [@@deriving to_yojson]

    type t =
      { pod_id: string
      ; new_node: State_hash.t option
      ; best_tip_changed: State_hash.t option
      ; root_transitioned: root_transitioned option }
    [@@deriving lens, to_yojson]

    let empty pod_id =
      {pod_id; new_node= None; best_tip_changed= None; root_transitioned= None}

    let register (lens : (t, 'a option) Lens.t) (result : t) (x : 'a) :
        t Or_error.t =
      match lens.get result with
      | Some _ ->
          Or_error.error_string
            "same transition frontier diff type unexpectedly encountered \
             twice in single application"
      | None ->
          Ok (lens.set (Some x) result)

    let parse log =
      let open Json_parsing in
      let open Or_error.Let_syntax in
      let%bind pod_id = find string log ["labels"; "k8s-pod/app"] in
      let%bind diffs =
        find (list json) log ["jsonPayload"; "metadata"; "diffs"]
      in
      or_error_list_fold diffs ~init:(empty pod_id) ~f:(fun res diff ->
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
                  let%bind garbage =
                    find (list state_hash) value ["garbage"]
                  in
                  let data = {new_root; garbage} in
                  register root_transitioned res data
              | _ ->
                  Or_error.error_string
                    "unexpected transition frontier diff name" )
          | _ ->
              Or_error.error_string
                "unexpected transition frontier diff format" )
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
      { block_height= 0
      ; epoch= 0
      ; global_slot= 0
      ; snarked_ledger_generated= false }

    (* Aggregated values for determining timeout conditions. Note: Slots passed and epochs passed are only determined if we produce a block. Add a log for these events to calculate these independently? *)
    type aggregated =
      { last_seen_result: t
      ; blocks_generated: int
      ; snarked_ledgers_generated: int }
    [@@deriving to_yojson]

    let empty_aggregated =
      { last_seen_result= empty
      ; blocks_generated= 0
      ; snarked_ledgers_generated= 0 }

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
    let parse log =
      let open Json_parsing in
      let open Or_error.Let_syntax in
      let breadcrumb = ["jsonPayload"; "metadata"; "breadcrumb"] in
      let breadcrumb_consensus_state =
        breadcrumb
        @ [ "validated_transition"
          ; "data"
          ; "protocol_state"
          ; "body"
          ; "consensus_state" ]
      in
      let%bind snarked_ledger_generated =
        find bool log (breadcrumb @ ["just_emitted_a_proof"])
      in
      let%bind block_height =
        find int log (breadcrumb_consensus_state @ ["blockchain_length"])
      in
      let%bind global_slot =
        find int log
          (breadcrumb_consensus_state @ ["curr_global_slot"; "slot_number"])
      in
      let%map epoch =
        find int log (breadcrumb_consensus_state @ ["epoch_count"])
      in
      {block_height; global_slot; epoch; snarked_ledger_generated}
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

  let existential_of_string = function
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
        existential_of_string string
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

  let event_type_module : type a.
      a t -> (module Event_type_intf with type t = a) = function
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
    String.Table.find table

  let log_filter_of_event_type = function
    | Event_type Log_error ->
        [ "jsonPayload.level=(\"Warn\" OR \"Error\" OR \"Faulty_peer\" OR \
           \"Fatal\")" ]
    | Event_type t ->
        let event_id =
          to_structured_event_id (Event_type t)
          |> Option.value_exn
               ~message:
                 "could not convert event type into log filter; no structured \
                  event id configured"
        in
        let filter =
          Printf.sprintf "jsonPayload.event_id=\"%s\""
            (Structured_log_events.string_of_id event_id)
        in
        [filter]

  let all_event_types_log_filter =
    let event_filters = List.map all_event_types ~f:log_filter_of_event_type in
    let nest s = "(" ^ s ^ ")" in
    let disjunction =
      event_filters
      |> List.map ~f:(fun filter ->
             nest (filter |> List.map ~f:nest |> String.concat ~sep:" AND ") )
      |> String.concat ~sep:" OR "
    in
    [disjunction]

  let parse_event (log : Yojson.Safe.t) : event Or_error.t =
    let open Json_parsing in
    let open Or_error.Let_syntax in
    match find string log ["jsonPayload"; "insertId"] with
    | Ok insert_id ->
        let (Event_type event_type) =
          of_structured_event_id insert_id
          |> Option.value_exn
               ~message:
                 "could not convert incoming event log into event type; no \
                  matching structured event id"
        in
        let (module Type) = event_type_module event_type in
        let%map data = Type.parse log in
        Event (event_type, data)
    | Error _ ->
        (* TODO: check log level to ensure it matches error log level *)
        let%map data = Log_error.parse log in
        Event (Log_error, data)

  let dispatch : type a b c. a t -> a -> b t -> (b -> c) -> c =
   fun t1 e t2 h ->
    let error () = failwith "TODO: better error message :)" in
    match (t1, t2) with
    | Log_error, Log_error ->
        h e
    | Node_initialization, Node_initialization ->
        h e
    | ( Transition_frontier_diff_application
      , Transition_frontier_diff_application ) ->
        h e
    | Block_produced, Block_produced ->
        h e
    | Breadcrumb_added, Breadcrumb_added ->
        h e
    | _ ->
        error ()

  (* TODO: tests on sexp and dispatch (etc) against all_event_types *)
end

(* TODO: think about buffering & temporal caching vs. network state subscriptions *)
module Event_router = struct
  module Event_handler_id = Unique_id.Int ()

  type ('a, 'b) handler_func = 'a -> [`Stop of 'b | `Continue] Deferred.t

  type event_handler =
    | Event_handler :
        Event_handler_id.t
        * 'b Ivar.t
        * 'a Event_type.t
        * ('a, 'b) handler_func
        -> event_handler

  let event_handler_id (Event_handler (id, _, _, _)) = id

  (* event subscriptions surface information from the handler (as type witnesses), but do not existentially hide the result parameter *)
  type _ event_subscription =
    | Event_subscription :
        Event_handler_id.t * 'b Ivar.t * 'a Event_type.t
        -> 'b event_subscription

  type handler_map = event_handler list Event_type.Map.t

  (* TODO: asynchronously unregistered event handlers *)
  type t =
    { logger: Logger.t
    ; subscription: Subscription.t
    ; handlers: handler_map ref
    ; cancel_ivar: unit Ivar.t
    ; background_job: unit Deferred.t }

  let unregister_event_handlers_by_id handlers event_type ids =
    handlers :=
      Event_type.Map.update !handlers event_type ~f:(fun registered_handlers ->
          registered_handlers |> Option.value ~default:[]
          |> List.filter ~f:(fun (Event_handler (registered_id, _, _, _)) ->
                 List.mem ids registered_id ~equal:Event_handler_id.equal ) )

  let dispatch_event handlers event =
    let open Event_type in
    let open Deferred.Let_syntax in
    let event_handlers =
      Map.find !handlers (type_of_event event) |> Option.value ~default:[]
    in
    (* This loop cannot directly mutate or recompute the handlers. Doing so will introduce a race condition. *)
    let%map ids_to_remove =
      Deferred.List.filter_map ~how:`Parallel event_handlers ~f:(fun handler ->
          (* assuming the dispatch for `f` is already parallel, and not the execution of the deferred it returns *)
          let (Event (event_type, event_data)) = event in
          let (Event_handler
                ( handler_id
                , handler_finished_ivar
                , handler_type
                , handler_callback )) =
            handler
          in
          match%map
            dispatch event_type event_data handler_type handler_callback
          with
          | `Continue ->
              None
          | `Stop result ->
              Ivar.fill handler_finished_ivar result ;
              Some handler_id )
    in
    unregister_event_handlers_by_id handlers
      (Event_type.type_of_event event)
      ids_to_remove

  let rec pull_subscription_in_background ~logger ~subscription ~handlers =
    let open Interruptible in
    let open Interruptible.Let_syntax in
    [%log debug] "Pulling StackDriver subscription" ;
    (* TODO: improved error reporting *)
    let%bind logs =
      uninterruptible
        (Deferred.map ~f:Core.Or_error.ok_exn (Subscription.pull subscription))
    in
    [%log debug] "Parsing events from logs" ;
    let%bind events =
      return
        (Core.Or_error.ok_exn
           (or_error_list_map logs ~f:Event_type.parse_event))
    in
    [%log debug] "Processing subscription events"
      ~metadata:
        [("events", `List (List.map events ~f:Event_type.event_to_yojson))] ;
    let%bind () =
      uninterruptible (Deferred.List.iter events ~f:(dispatch_event handlers))
    in
    let%bind () = uninterruptible (after (Time.Span.of_ms 10000.0)) in
    (* this extra bind point allows the interruptible monad to interrupt after the timeout *)
    let%bind () = return () in
    pull_subscription_in_background ~logger ~subscription ~handlers

  let start_background_job ~logger ~subscription ~handlers ~cancel_ivar =
    let job =
      let open Interruptible.Let_syntax in
      let%bind () = Interruptible.lift Deferred.unit (Ivar.read cancel_ivar) in
      pull_subscription_in_background ~logger ~subscription ~handlers
    in
    let finished_ivar = Ivar.create () in
    Interruptible.don't_wait_for
      (Interruptible.finally job ~f:(fun () -> Ivar.fill finished_ivar ())) ;
    Ivar.read finished_ivar

  let create ~logger ~subscription =
    let cancel_ivar = Ivar.create () in
    let handlers = ref Event_type.Map.empty in
    let background_job =
      start_background_job ~logger ~subscription ~handlers ~cancel_ivar
    in
    {logger; subscription; handlers; cancel_ivar; background_job}

  let stop t =
    Ivar.fill_if_empty t.cancel_ivar () ;
    t.background_job

  let on t event_type ~f =
    let event_type_ex = Event_type.Event_type event_type in
    let handler_id = Event_handler_id.create () in
    let finished_ivar = Ivar.create () in
    let handler = Event_handler (handler_id, finished_ivar, event_type, f) in
    t.handlers :=
      Event_type.Map.add_multi !(t.handlers) ~key:event_type_ex ~data:handler ;
    Event_subscription (handler_id, finished_ivar, event_type)

  (* TODO: On cancellation, should we notify active subscriptions? Would involve changing await type to option or result. *)
  let cancel t event_subscription cancellation =
    let (Event_subscription (id, ivar, event_type)) = event_subscription in
    unregister_event_handlers_by_id t.handlers
      (Event_type.Event_type event_type) [id] ;
    Ivar.fill ivar cancellation

  let await event_subscription =
    let (Event_subscription (_, ivar, _)) = event_subscription in
    Ivar.read ivar

  let await_with_timeout t event_subscription ~timeout_duration
      ~timeout_cancellation =
    let open Deferred.Let_syntax in
    match%map
      Timeout.await () ~timeout_duration (await event_subscription)
    with
    | `Ok x ->
        x
    | `Timeout ->
        cancel t event_subscription timeout_cancellation ;
        timeout_cancellation
end

type errors =
  { warn: Event_type.Log_error.t DynArray.t
  ; error: Event_type.Log_error.t DynArray.t
  ; faulty_peer: Event_type.Log_error.t DynArray.t
  ; fatal: Event_type.Log_error.t DynArray.t }

let empty_errors () =
  { warn= DynArray.create ()
  ; error= DynArray.create ()
  ; faulty_peer= DynArray.create ()
  ; fatal= DynArray.create () }

type constants =
  { constraints: Genesis_constants.Constraint_constants.t
  ; genesis: Genesis_constants.t }

type t =
  { logger: Logger.t
  ; constants: constants
  ; subscription: Subscription.t
  ; event_router: Event_router.t
  ; error_accumulator: errors
  ; initialization_table: unit Ivar.t String.Map.t
  ; best_tip_map_reader: State_hash.t String.Map.t Broadcast_pipe.Reader.t
  ; best_tip_map_writer: State_hash.t String.Map.t Broadcast_pipe.Writer.t }

let watch_log_errors ~logger ~event_router ~on_fatal_error =
  let error_accumulator = empty_errors () in
  ignore
    (Event_router.on event_router Event_type.Log_error ~f:(fun log_error ->
         let open Event_type.Log_error in
         let acc =
           match log_error.message.level with
           | Warn ->
               error_accumulator.warn
           | Error ->
               error_accumulator.error
           | Faulty_peer ->
               error_accumulator.faulty_peer
           | Fatal ->
               error_accumulator.fatal
           | _ ->
               failwith "unexpected log level encountered"
         in
         DynArray.add acc log_error ;
         if log_error.message.level = Fatal then (
           [%log fatal] "Error occured $error"
             ~metadata:[("error", Logger.Message.to_yojson log_error.message)] ;
           on_fatal_error log_error.message ) ;
         Deferred.return `Continue )) ;
  error_accumulator

let watch_node_initializations ~logger ~event_router ~network =
  (* TODO: redo initialization table (support multiple fills, staging/unstaging expectations) *)
  let initialization_table =
    let open Kubernetes_network.Node in
    Kubernetes_network.all_nodes network
    |> List.map ~f:(fun (node : Kubernetes_network.Node.t) ->
           (node.pod_id, Ivar.create ()) )
    |> String.Map.of_alist_exn
  in
  ignore
    (Event_router.on event_router Event_type.Node_initialization
       ~f:(fun node_init ->
         let open Event_type.Node_initialization in
         let ivar =
           match String.Map.find initialization_table node_init.pod_id with
           | None ->
               failwithf "Node not found in initialization table: %s"
                 node_init.pod_id ()
           | Some ivar ->
               ivar
         in
         if Ivar.is_empty ivar then (
           Ivar.fill ivar () ;
           return `Continue )
         else (
           [%log warn]
             "Received initialization for node that has already initialized" ;
           return `Continue ) )) ;
  initialization_table

let watch_best_tips ~event_router =
  let best_tip_map_reader, best_tip_map_writer =
    Broadcast_pipe.create String.Map.empty
  in
  ignore
    (Event_router.on event_router
       Event_type.Transition_frontier_diff_application
       ~f:(fun diff_application ->
         Option.value_map diff_application.best_tip_changed
           ~default:(return `Continue)
           ~f:(fun new_best_tip ->
             let best_tip_map =
               Broadcast_pipe.Reader.peek best_tip_map_reader
             in
             let best_tip_map' =
               String.Map.set best_tip_map ~key:diff_application.pod_id
                 ~data:new_best_tip
             in
             let%map () =
               Broadcast_pipe.Writer.write best_tip_map_writer best_tip_map'
             in
             `Continue ) )) ;
  (best_tip_map_reader, best_tip_map_writer)

let create ~logger ~(network : Kubernetes_network.t) ~on_fatal_error =
  Deferred.bind ~f:Malleable_error.of_or_error_hard
    (let open Deferred.Or_error.Let_syntax in
    let log_filter =
      let coda_container_filter = "resource.labels.container_name=\"coda\"" in
      let filters =
        [network.testnet_log_filter; coda_container_filter]
        @ Event_type.all_event_types_log_filter
      in
      String.concat filters ~sep:"\n"
    in
    let%map subscription =
      Subscription.create ~logger ~name:"integration_test_events"
        ~filter:log_filter
    in
    [%log info] "Event subscription created" ;
    let event_router = Event_router.create ~logger ~subscription in
    let error_accumulator =
      watch_log_errors ~logger ~event_router ~on_fatal_error
    in
    let initialization_table =
      watch_node_initializations ~logger ~event_router ~network
    in
    let best_tip_map_reader, best_tip_map_writer =
      watch_best_tips ~event_router
    in
    { logger
    ; constants=
        { constraints= network.constraint_constants
        ; genesis= network.genesis_constants }
    ; subscription
    ; event_router
    ; error_accumulator
    ; initialization_table
    ; best_tip_map_writer
    ; best_tip_map_reader })

let destroy t : Test_error.Set.t Malleable_error.t =
  let open Malleable_error.Let_syntax in
  let { constants= _
      ; logger
      ; subscription
      ; event_router
      ; initialization_table= _
      ; best_tip_map_reader= _
      ; best_tip_map_writer
      ; error_accumulator } =
    t
  in
  let%map () =
    Deferred.bind
      ~f:(Malleable_error.of_or_error_soft ())
      (let open Deferred.Or_error.Let_syntax in
      let%bind () =
        Deferred.map (Event_router.stop event_router) ~f:Or_error.return
      in
      Broadcast_pipe.Writer.close best_tip_map_writer ;
      Subscription.delete subscription)
  in
  [%log debug] "subscription deleted" ;
  let lift error_array =
    DynArray.to_list error_array
    |> List.map ~f:(fun {Event_type.Log_error.pod_id; message} ->
           Test_error.Remote_error {node_id= pod_id; error_message= message} )
  in
  let soft_errors =
    lift error_accumulator.warn @ lift error_accumulator.faulty_peer
  in
  let hard_errors =
    lift error_accumulator.error @ lift error_accumulator.fatal
  in
  {Test_error.Set.soft_errors; hard_errors}

(*TODO: Node status. Should that be a part of a node query instead? or we need a new log that has status info and some node identifier*)
let wait_for' :
       blocks:int
    -> epoch_reached:int
    -> snarked_ledgers_generated:int
    -> timeout:[ `Slots of int
               | `Epochs of int
               | `Snarked_ledgers_generated of int
               | `Milliseconds of int64 ]
    -> t
    -> ( [> `Blocks_produced of int]
       * [> `Slots_passed of int]
       * [> `Snarked_ledgers_generated of int] )
       Malleable_error.t =
 fun ~blocks ~epoch_reached ~snarked_ledgers_generated ~timeout t ->
  if
    blocks = 0 && epoch_reached = 0
    && snarked_ledgers_generated = 0
    && timeout = `Milliseconds 0L
  then
    Malleable_error.return
      (`Blocks_produced 0, `Slots_passed 0, `Snarked_ledgers_generated 0)
  else
    let now = Time.now () in
    let hard_timeout =
      let ( ! ) = Int64.of_int in
      let ( * ) = Int64.( * ) in
      let ( +! ) = Int64.( + ) in
      let estimated_time =
        match timeout with
        | `Slots n ->
            !n * !(t.constants.constraints.block_window_duration_ms)
        | `Epochs n ->
            !n
            * !(t.constants.genesis.protocol.slots_per_epoch)
            * !(t.constants.constraints.block_window_duration_ms)
        | `Snarked_ledgers_generated n ->
            (* Assuming at least 1/3 rd of the max throughput otherwise this could take forever depending on the scan state size*)
            (*first snarked ledger*)
            3L
            * !(t.constants.constraints.block_window_duration_ms)
            * ( !(t.constants.constraints.work_delay + 1)
                * !(t.constants.constraints.transaction_capacity_log_2 + 1)
              +! 1L )
            +! (*subsequent snarked ledgers*)
               !(n - 1)
               * !(t.constants.constraints.block_window_duration_ms)
               * 3L
        | `Milliseconds n ->
            n
      in
      Time.Span.of_ms (Int64.to_float (estimated_time * 2L))
    in
    let query_timeout_ms =
      match timeout with
      | `Milliseconds x ->
          Some (Time.add now (Time.Span.of_ms (Int64.to_float x)))
      | _ ->
          None
    in
    let timed_out (res : Event_type.Block_produced.aggregated) =
      match timeout with
      | `Slots x ->
          res.last_seen_result.global_slot >= x
      | `Epochs x ->
          res.last_seen_result.epoch >= x
      | `Snarked_ledgers_generated x ->
          res.snarked_ledgers_generated >= x
      | `Milliseconds _ ->
          Time.( > ) (Time.now ()) (Option.value_exn query_timeout_ms)
    in
    let conditions_met (aggregated : Event_type.Block_produced.aggregated) =
      [%log' info t.logger]
        ~metadata:
          [ ( "result"
            , Event_type.Block_produced.aggregated_to_yojson aggregated )
          ; ("blocks", `Int blocks)
          ; ("epoch_reached", `Int epoch_reached)
          ; ("snarked_ledgers_generated", `Int snarked_ledgers_generated) ]
        "Checking if conditions passed for $result [expected blocks=$blocks, \
         expected epochs reached=$epoch_reached, expected snarked ledgers \
         generated=$snarked_ledgers_generated]" ;
      aggregated.last_seen_result.block_height > blocks
      && aggregated.last_seen_result.epoch >= epoch_reached
      && aggregated.snarked_ledgers_generated >= snarked_ledgers_generated
    in
    (* TODO: Event_router.on_fold to thread state through handlers without refs *)
    let aggregated_ref = ref Event_type.Block_produced.empty_aggregated in
    let handle_block_produced block_produced =
      let aggregated =
        Event_type.Block_produced.aggregate !aggregated_ref block_produced
      in
      aggregated_ref := aggregated ;
      if timed_out aggregated then Deferred.return (`Stop `State_timeout)
      else if conditions_met aggregated then
        Deferred.return (`Stop (`Conditions_met aggregated))
      else Deferred.return `Continue
    in
    let%bind result =
      Event_router.on t.event_router Event_type.Block_produced
        ~f:handle_block_produced
      |> Event_router.await_with_timeout t.event_router
           ~timeout_duration:hard_timeout ~timeout_cancellation:`Hard_timeout
    in
    match result with
    | `Hard_timeout ->
        Malleable_error.of_string_hard_error "wait_for hit a hard timeout"
    | `State_timeout ->
        Malleable_error.of_string_hard_error "wait_for hit a state timeout"
    | `Conditions_met aggregated ->
        let open Event_type.Block_produced in
        Malleable_error.return
          ( `Blocks_produced aggregated.blocks_generated
          , `Slots_passed aggregated.last_seen_result.global_slot
          , `Snarked_ledgers_generated aggregated.snarked_ledgers_generated )

let wait_for :
       ?blocks:int
    -> ?epoch_reached:int
    -> ?snarked_ledgers_generated:int
    -> ?timeout:[ `Slots of int
                | `Epochs of int
                | `Snarked_ledgers_generated of int
                | `Milliseconds of int64 ]
    -> t
    -> ( [> `Blocks_produced of int]
       * [> `Slots_passed of int]
       * [> `Snarked_ledgers_generated of int] )
       Malleable_error.t =
 fun ?(blocks = 0) ?(epoch_reached = 0) ?(snarked_ledgers_generated = 0)
     ?(timeout = `Milliseconds 300000L) t ->
  [%log' info t.logger]
    ~metadata:
      [ ("blocks", `Int blocks)
      ; ("epoch", `Int epoch_reached)
      ; ("snarked_ledgers_generated", `Int snarked_ledgers_generated)
      ; ( "timeout"
        , `String
            ( match timeout with
            | `Slots n ->
                Printf.sprintf "%d slots" n
            | `Epochs n ->
                Printf.sprintf "%d epochs" n
            | `Snarked_ledgers_generated n ->
                Printf.sprintf "%d snarked ledgers emitted" n
            | `Milliseconds n ->
                Printf.sprintf "%Ld ms" n ) ) ]
    "Waiting for $blocks blocks, $epoch epoch, $snarked_ledgers_generated \
     snarked ledgers with timeout $timeout" ;
  match%bind
    wait_for' ~blocks ~epoch_reached ~snarked_ledgers_generated ~timeout t
  with
  | Error {Malleable_error.Hard_fail.hard_error= e; soft_errors= se} ->
      [%log' fatal t.logger] "wait_for failed with error: $error"
        ~metadata:[("error", Error_json.error_to_yojson e.error)] ;
      Deferred.return
        (Error {Malleable_error.Hard_fail.hard_error= e; soft_errors= se})
  | res ->
      Deferred.return res

let command_matches_payment cmd ~sender ~receiver ~amount =
  let open User_command in
  match cmd with
  | Signed_command signed_cmd -> (
      let open Signature_lib in
      let body =
        Signed_command.payload signed_cmd |> Signed_command_payload.body
      in
      match body with
      | Payment {source_pk; receiver_pk; amount= paid_amt; token_id= _}
        when Public_key.Compressed.equal source_pk sender
             && Public_key.Compressed.equal receiver_pk receiver
             && Currency.Amount.equal paid_amt amount ->
          true
      | _ ->
          false )
  | Snapp_command _ ->
      false

let wait_for_payment ?(timeout_duration = Time.Span.of_ms 900.0) t ~logger
    ~sender ~receiver ~amount () : unit Malleable_error.t =
  let open Signature_lib in
  let open Event_type.Breadcrumb_added in
  let handle_breadcrumb_added breadcrumb_added =
    let payment_opt =
      List.find breadcrumb_added.user_commands ~f:(fun cmd_with_status ->
          cmd_with_status.With_status.data |> User_command.forget_check
          |> command_matches_payment ~sender ~receiver ~amount )
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
        if was_applied then Deferred.return (`Stop `Payment_found)
        else Deferred.return (`Stop (`Payment_not_applied actual_status))
    | None ->
        Deferred.return `Continue
  in
  let%bind result =
    Event_router.await_with_timeout t.event_router ~timeout_duration
      ~timeout_cancellation:`Timeout
      (Event_router.on t.event_router Event_type.Breadcrumb_added
         ~f:handle_breadcrumb_added)
  in
  match result with
  | `Timeout ->
      Malleable_error.of_string_hard_error "timed out waiting for payment"
  | `Payment_not_applied actual_status ->
      [%log info]
        "wait_for_payment: found matching payment, but status is not 'Applied'"
        ~metadata:
          [ ("sender", `String (Public_key.Compressed.to_string sender))
          ; ("receiver", `String (Public_key.Compressed.to_string receiver))
          ; ("amount", `String (Currency.Amount.to_string amount))
          ; ( "actual_user_command_status"
            , Transaction_status.to_yojson actual_status ) ] ;
      Malleable_error.of_string_hard_error_format
        "Unexpected status in matching payment: %s"
        (Transaction_status.to_yojson actual_status |> Yojson.Safe.to_string)
  | `Payment_found ->
      [%log info] "wait_for_payment: found matching payment"
        ~metadata:
          [ ("sender", `String (Public_key.Compressed.to_string sender))
          ; ("receiver", `String (Public_key.Compressed.to_string receiver))
          ; ("amount", `String (Currency.Amount.to_string amount)) ] ;
      Malleable_error.return ()

let await_timeout ~waiting_for ~timeout_duration ~logger deferred =
  match%bind Timeout.await ~timeout_duration () deferred with
  | `Timeout ->
      Malleable_error.of_string_hard_error_format
        "timeout while waiting for %s" waiting_for
  | `Ok x ->
      [%log info] "%s completed" waiting_for ;
      Malleable_error.return x

let wait_for_init (node : Kubernetes_network.Node.t) t =
  let open Malleable_error.Let_syntax in
  [%log' info t.logger]
    ~metadata:[("node", `String node.pod_id)]
    "Waiting for $node to initialize" ;
  let%bind init =
    Malleable_error.of_option_hard
      (String.Map.find t.initialization_table node.pod_id)
      "failed to find node in initialization table"
  in
  if Ivar.is_full init then return ()
  else
    (* TODO: make configurable (or ideally) compute dynamically from network configuration *)
    await_timeout ~waiting_for:"initialization"
      ~timeout_duration:(Time.Span.of_ms (15.0 *. 60.0 *. 1000.0))
      (Ivar.read init) ~logger:t.logger

(* TODO: rewrite with event router *)
let wait_for_sync (nodes : Kubernetes_network.Node.t list) ~timeout t =
  [%log' info t.logger]
    ~metadata:[("nodes", `List (List.map ~f:(fun n -> `String n.pod_id) nodes))]
    "Waiting for $nodes to synchronize" ;
  let pod_ids = List.map nodes ~f:(fun node -> node.pod_id) in
  let all_equal ls =
    Option.value_map (List.hd ls) ~default:true ~f:(fun h ->
        [h] = List.find_all_dups ~compare:State_hash.compare ls )
  in
  let all_nodes_synced best_tip_map =
    if List.for_all pod_ids ~f:(String.Map.mem best_tip_map) then
      (* [lookup_exn] should never throw an exception here *)
      all_equal (List.map pod_ids ~f:(String.Map.find_exn best_tip_map))
    else false
  in
  [%log' info t.logger] "waiting for %f seconds" (Time.Span.to_sec timeout) ;
  await_timeout
    (Broadcast_pipe.Reader.iter_until t.best_tip_map_reader
       ~f:(Fn.compose Deferred.return all_nodes_synced))
    ~waiting_for:"synchronization" ~timeout_duration:timeout ~logger:t.logger

(*TODO: unit tests without conencting to gcloud. The following test connects to joyous-occasion*)
(*let%test_module "Log tests" =
  ( module struct
    let logger = Logger.create ()

    let testnet : Kubernetes_network.t =
      let k8 = "k8s_container" in
      let location = "us-east1" in
      let cluster_name = "coda-infra-east" in
      let testnet_name = "joyous-occasion" in
      { block_producers= []
      ; snark_coordinators= []
      ; archive_nodes= []
      ; testnet_log_filter=
          String.concat ~sep:" "
            [ "resource.type="
            ; k8
            ; "resource.labels.location="
            ; location
            ; "resource.labels.cluster_name="
            ; cluster_name
            ; "resource.labels.namespace_name="
            ; testnet_name ] }

    let wait_for_block_height () =
      let open Deferred.Or_error.Let_syntax in
      let%bind log_engine = create ~logger testnet in
      let%bind _ = wait_for ~blocks:2500 log_engine in
      delete log_engine

    let wait_for_slot_timeout () =
      let open Deferred.Or_error.Let_syntax in
      let%bind log_engine = create ~logger testnet in
      let%bind _ = wait_for ~timeout:(`Slots 2) log_engine in
      delete log_engine

    let wait_for_epoch () =
      let open Deferred.Or_error.Let_syntax in
      let%bind log_engine = create ~logger testnet in
      let%bind _ = wait_for ~epoch_reached:16 log_engine in
      delete log_engine

    let test_exn f () =
      let%map res = f () in
      Or_error.ok_exn res

    let%test_unit "joyous-occasion - wait_for_block_height" =
      Async.Thread_safe.block_on_async_exn (test_exn wait_for_block_height)

    let%test_unit "joyous-occasion - wait_for_slot_timeout" =
      Async.Thread_safe.block_on_async_exn (test_exn wait_for_slot_timeout)

    let%test_unit "joyous-occasion - wait_for_epoch" =
      Async.Thread_safe.block_on_async_exn (test_exn wait_for_epoch)
  end )*)
