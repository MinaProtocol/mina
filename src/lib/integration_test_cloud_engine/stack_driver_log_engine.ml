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

let log_filter_of_event_type =
  let open Event_type in
  function
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
  let event_filters =
    List.map Event_type.all_event_types ~f:log_filter_of_event_type
  in
  let nest s = "(" ^ s ^ ")" in
  let disjunction =
    event_filters
    |> List.map ~f:(fun filter ->
           nest (filter |> List.map ~f:nest |> String.concat ~sep:" AND ") )
    |> String.concat ~sep:" OR "
  in
  [disjunction]

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

(* TODO: think about buffering & temporal caching vs. network state subscriptions *)
module Event_router = struct
  module Event_handler_id = Unique_id.Int ()

  type ('a, 'b) handler_func =
    Kubernetes_network.Node.t -> 'a -> [`Stop of 'b | `Continue] Deferred.t

  type event_handler =
    | Event_handler :
        Event_handler_id.t
        * 'b Ivar.t
        * 'a Event_type.t
        * ('a, 'b) handler_func
        -> event_handler

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

  let dispatch_event handlers node event =
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
            dispatch_exn event_type event_data handler_type
              (handler_callback node)
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

  let rec pull_subscription_in_background ~logger ~network ~subscription
      ~handlers =
    let open Interruptible in
    let open Interruptible.Let_syntax in
    let module Or_error = Core.Or_error in
    [%log debug] "Pulling StackDriver subscription" ;
    (* TODO: improved error reporting *)
    let%bind log_entries =
      uninterruptible
        (Deferred.map ~f:Or_error.ok_exn (Subscription.pull subscription))
    in
    [%log debug] "Parsing events from logs" ;
    let%bind events_with_nodes =
      return
        (Or_error.ok_exn
           (or_error_list_map log_entries ~f:(fun log_entry ->
                let open Or_error.Let_syntax in
                let open Json_parsing in
                let%bind app_id =
                  find string log_entry ["labels"; "k8s-pod/app"]
                in
                let%bind node =
                  Kubernetes_network.lookup_node_by_app_id network app_id
                  |> Option.value_map ~f:Or_error.return
                       ~default:
                         (Or_error.errorf
                            "failed to find node by pod app id \"%s\"" app_id)
                in
                let%bind log =
                  find
                    (parser_from_of_yojson Logger.Message.of_yojson)
                    log_entry ["jsonPayload"]
                in
                let%map event = Event_type.parse_event log in
                (event, node) )))
    in
    [%log debug] "Processing subscription events"
      ~metadata:
        [ ( "events"
          , `List
              (List.map events_with_nodes ~f:(fun (event, _) ->
                   Event_type.event_to_yojson event )) ) ] ;
    let%bind () =
      uninterruptible
        (Deferred.List.iter events_with_nodes ~f:(fun (event, node) ->
             dispatch_event handlers node event ))
    in
    let%bind () = uninterruptible (after (Time.Span.of_ms 10000.0)) in
    (* this extra bind point allows the interruptible monad to interrupt after the timeout *)
    let%bind () = return () in
    pull_subscription_in_background ~logger ~network ~subscription ~handlers

  let start_background_job ~logger ~network ~subscription ~handlers
      ~cancel_ivar =
    let job =
      let open Interruptible.Let_syntax in
      let%bind () = Interruptible.lift Deferred.unit (Ivar.read cancel_ivar) in
      pull_subscription_in_background ~logger ~network ~subscription ~handlers
    in
    let finished_ivar = Ivar.create () in
    Interruptible.don't_wait_for
      (Interruptible.finally job ~f:(fun () -> Ivar.fill finished_ivar ())) ;
    Ivar.read finished_ivar

  let create ~logger ~network ~subscription =
    let cancel_ivar = Ivar.create () in
    let handlers = ref Event_type.Map.empty in
    let background_job =
      start_background_job ~logger ~network ~subscription ~handlers
        ~cancel_ivar
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

type log_error = Kubernetes_network.Node.t * Event_type.Log_error.t

type errors =
  { warn: log_error DynArray.t
  ; error: log_error DynArray.t
  ; faulty_peer: log_error DynArray.t
  ; fatal: log_error DynArray.t }

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
    (Event_router.on event_router Event_type.Log_error ~f:(fun node message ->
         let open Logger.Message in
         let acc =
           match message.level with
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
         DynArray.add acc (node, message) ;
         if message.level = Fatal then (
           [%log fatal] "Error occured $error"
             ~metadata:[("error", Logger.Message.to_yojson message)] ;
           on_fatal_error message ) ;
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
       ~f:(fun node () ->
         let ivar =
           match String.Map.find initialization_table node.pod_id with
           | None ->
               failwithf "Node not found in initialization table: %s"
                 node.pod_id ()
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
       ~f:(fun node diff_application ->
         Option.value_map diff_application.best_tip_changed
           ~default:(return `Continue)
           ~f:(fun new_best_tip ->
             let best_tip_map =
               Broadcast_pipe.Reader.peek best_tip_map_reader
             in
             let best_tip_map' =
               String.Map.set best_tip_map ~key:node.pod_id ~data:new_best_tip
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
        @ all_event_types_log_filter
      in
      String.concat filters ~sep:"\n"
    in
    let%map subscription =
      Subscription.create ~logger ~name:"integration_test_events"
        ~filter:log_filter
    in
    [%log info] "Event subscription created" ;
    let event_router = Event_router.create ~logger ~network ~subscription in
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
    |> List.map ~f:(fun (node, message) ->
           let open Kubernetes_network.Node in
           Test_error.Remote_error
             {node_id= node.pod_id; error_message= message} )
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
    let handle_block_produced _node block_produced =
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
  let handle_breadcrumb_added _node breadcrumb_added =
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
