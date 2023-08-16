open Async
open Core
open Integration_test_lib
module Timeout = Timeout_lib.Core_time
module Node = Kubernetes_network.Node

(** This implements Log_engine_intf for integration tests, by creating a simple system that polls a mina daemon's graphql endpoint for fetching logs*)

let log_filter_of_event_type ev_existential =
  let open Event_type in
  let (Event_type ev_type) = ev_existential in
  let (module Ty) = event_type_module ev_type in
  match Ty.parse with
  | From_error_log _ ->
      [] (* TODO: Do we need this? *)
  | From_daemon_log (struct_id, _) ->
      [ Structured_log_events.string_of_id struct_id ]
  | From_puppeteer_log _ ->
      []
(* TODO: Do we need this? *)

let all_event_types_log_filter =
  List.bind ~f:log_filter_of_event_type Event_type.all_event_types

type t =
  { logger : Logger.t
  ; event_writer : (Node.t * Event_type.event) Pipe.Writer.t
  ; event_reader : (Node.t * Event_type.event) Pipe.Reader.t
  ; background_job : unit Deferred.Or_error.t
  }

let event_reader { event_reader; _ } = event_reader

let parse_event_from_log_entry ~logger log_entry =
  let open Or_error.Let_syntax in
  let open Json_parsing in
  Or_error.try_with_join (fun () ->
      let payload = Yojson.Safe.from_string log_entry in
      let%map event =
        let%bind msg =
          parse (parser_from_of_yojson Logger.Message.of_yojson) payload
        in
        let event_id =
          Option.map ~f:Structured_log_events.string_of_id msg.event_id
        in
        [%log spam] "parsing daemon structured event, event_id = $event_id"
          ~metadata:[ ("event_id", [%to_yojson: string option] event_id) ] ;
        match msg.event_id with
        | Some _ ->
            Event_type.parse_daemon_event msg
        | None ->
            (* Currently unreachable, but we could include error logs here if
               desired.
            *)
            Event_type.parse_error_log msg
      in
      event )

let rec get_filtered_log_entries_of_node ~logger ~event_writer
    ~last_log_index_seen node =
  let open Deferred.Let_syntax in
  if not (Pipe.is_closed event_writer) then (
    let%bind () = after (Time.Span.of_ms 10000.0) in
    match%bind
      Integration_test_lib.Graphql_requests.get_filtered_log_entries
        ~last_log_index_seen
        (Node.get_ingress_uri node)
    with
    | Ok log_entries ->
        Array.iter log_entries ~f:(fun log_entry ->
            match parse_event_from_log_entry ~logger log_entry with
            | Ok a ->
                Pipe.write_without_pushback_if_open event_writer (node, a)
            | Error e ->
                [%log warn] "Error parsing log $error"
                  ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ) ;
        let last_log_index_seen =
          Array.length log_entries + last_log_index_seen
        in
        get_filtered_log_entries_of_node ~logger ~event_writer
          ~last_log_index_seen node
    | Error err ->
        [%log error] "Encountered an error while polling $node for logs: $err"
          ~metadata:
            [ ("node", `String node.app_id)
            ; ("err", Error_json.error_to_yojson err)
            ] ;
        (* Emit an event that declares the node to be down. *)
        Pipe.write_without_pushback_if_open event_writer
          (node, Event (Node_down, ())) ;
        (* Don't keep looping, the node may be restarting. *)
        return (Ok ()) )
  else Deferred.Or_error.error_string "Event writer closed"

let rec start_filtered_log_of_node ~logger ~log_filter ~event_writer node =
  let open Deferred.Let_syntax in
  if not (Pipe.is_closed event_writer) then
    match%bind
      Integration_test_lib.Graphql_requests.start_filtered_log ~logger
        ~log_filter
        (Node.get_ingress_uri node)
    with
    | Ok () ->
        return (Ok ())
    | Error _ ->
        start_filtered_log_of_node ~logger ~log_filter ~event_writer node
  else Deferred.Or_error.error_string "Event writer closed"

let rec poll_node_for_logs_in_background ~log_filter ~logger ~event_writer
    (node : Node.t) =
  let open Deferred.Or_error.Let_syntax in
  [%log info] "Requesting for $node to start its filtered logs"
    ~metadata:[ ("node", `String node.app_id) ] ;
  let%bind () =
    start_filtered_log_of_node ~logger ~log_filter ~event_writer node
  in
  [%log info] "$node has started its filtered logs. Beginning polling"
    ~metadata:[ ("node", `String node.app_id) ] ;
  let%bind () =
    (* if all goes well, the program will stay in the recursive function get_filtered_log_entries_of_node for good... *)
    get_filtered_log_entries_of_node ~last_log_index_seen:0 ~logger
      ~event_writer node
  in
  (* if the above recursive function fails, then the program falls through down to here, where this function will call itself to start over the logic of starting the filtered log and continuing again *)
  poll_node_for_logs_in_background ~log_filter ~logger ~event_writer node

let poll_for_logs_in_background ~log_filter ~logger ~network ~event_writer =
  Kubernetes_network.all_pods network
  |> Core.String.Map.data
  |> Deferred.Or_error.List.iter ~how:`Parallel
       ~f:(poll_node_for_logs_in_background ~log_filter ~logger ~event_writer)

let create ~logger ~(network : Kubernetes_network.t) =
  let open Deferred.Or_error.Let_syntax in
  let log_filter = all_event_types_log_filter in
  let event_reader, event_writer = Pipe.create () in
  let background_job =
    poll_for_logs_in_background ~log_filter ~logger ~network ~event_writer
  in
  return { logger; event_reader; event_writer; background_job }

let destroy t : unit Deferred.Or_error.t =
  let open Deferred.Or_error.Let_syntax in
  let { logger; event_reader = _; event_writer; background_job = _ } = t in
  Pipe.close event_writer ;
  [%log debug] "graphql polling log engine destroyed" ;
  return ()
