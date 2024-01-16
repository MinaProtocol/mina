open Async
open Core
module Timeout = Timeout_lib.Core_time

(** This implements Log_engine_intf for integration tests, by creating a simple system that polls a mina daemon's graphql endpoint for fetching logs*)

module Make_GraphQL_polling_log_engine
    (Network : Intf.Engine.Network_intf) (Polling_interval : sig
      val start_filtered_logs_interval : Time.Span.t
    end) =
struct
  module Node = Network.Node

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

  let rec filtered_log_entries_poll node ~logger ~event_writer
      ~last_log_index_seen =
    let open Deferred.Let_syntax in
    if not (Pipe.is_closed event_writer) then (
      let%bind () = after (Time.Span.of_ms 10000.0) in
      match%bind
        Graphql_requests.get_filtered_log_entries
          (Node.get_ingress_uri node)
          ~last_log_index_seen
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
          filtered_log_entries_poll node ~logger ~event_writer
            ~last_log_index_seen
      | Error err ->
          [%log error] "Encountered an error while polling $node for logs: $err"
            ~metadata:
              [ ("node", `String (Node.infra_id node))
              ; ("err", Error_json.error_to_yojson err)
              ] ;
          (* Declare the node to be offline. *)
          Pipe.write_without_pushback_if_open event_writer
            (node, Event (Node_offline, ())) ;
          (* Don't keep looping, the node may be restarting. *)
          return (Ok ()) )
    else Deferred.Or_error.error_string "Event writer closed"

  let rec start_filtered_log node ~logger ~log_filter ~event_writer =
    let open Deferred.Let_syntax in
    if not (Pipe.is_closed event_writer) then
      match%bind
        Graphql_requests.start_filtered_log ~logger ~log_filter
          ~retry_delay_sec:
            (Polling_interval.start_filtered_logs_interval |> Time.Span.to_sec)
          (Node.get_ingress_uri node)
      with
      | Ok () ->
          return (Ok ())
      | Error _ ->
          start_filtered_log node ~logger ~log_filter ~event_writer
    else Deferred.Or_error.error_string "Event writer closed"

  let rec poll_node_for_logs_in_background ~log_filter ~logger ~event_writer
      (node : Node.t) =
    let open Deferred.Or_error.Let_syntax in
    [%log info] "Requesting for $node to start its filtered logs"
      ~metadata:[ ("node", `String (Node.infra_id node)) ] ;
    let%bind () = start_filtered_log ~logger ~log_filter ~event_writer node in
    [%log info] "$node has started its filtered logs. Beginning polling"
      ~metadata:[ ("node", `String (Node.infra_id node)) ] ;
    let%bind () =
      filtered_log_entries_poll node ~last_log_index_seen:0 ~logger
        ~event_writer
    in
    poll_node_for_logs_in_background ~log_filter ~logger ~event_writer node

  let poll_for_logs_in_background ~log_filter ~logger ~network ~event_writer =
    Network.all_nodes network |> Core.String.Map.data
    |> Deferred.Or_error.List.iter ~how:`Parallel
         ~f:(poll_node_for_logs_in_background ~log_filter ~logger ~event_writer)

  let create ~logger ~(network : Network.t) =
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
end
