open Async
open Core

(* open Integration_test_lib.Util *)
open Integration_test_lib
module Timeout = Timeout_lib.Core_time
module Node = Kubernetes_network.Node

(** This implements Log_engine_intf for integration tests, by creating a simple system that polls a mina daemon's graphql endpoint for fetching logs*)

(* let yojson_from_string json_str =
   Or_error.try_with (fun () -> Yojson.Safe.from_string json_str) *)

(* let or_error_list_fold ls ~init ~f =
     let open Or_error.Let_syntax in
     List.fold ls ~init:(return init) ~f:(fun acc_or_error el ->
         let%bind acc = acc_or_error in
         f acc el )

   let or_error_list_map ls ~f =
     let open Or_error.Let_syntax in
     or_error_list_fold ls ~init:[] ~f:(fun t el ->
         let%map h = f el in
         h :: t ) *)

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

(* TODO this is gonna be structured different from the stack driver log engine *)
let parse_event_from_log_entry ~logger ~network log_entry =
  let open Or_error.Let_syntax in
  let open Json_parsing in
  let%bind pod_id =
    find string log_entry [ "resource"; "labels"; "pod_name" ]
  in
  let%bind _, node =
    Kubernetes_network.lookup_node_by_pod_id network pod_id
    |> Option.value_map ~f:Or_error.return
         ~default:
           (Or_error.errorf
              "failed to find node by pod id \"%s\"; known pod ids = [%s]"
              pod_id
              (Kubernetes_network.all_pod_ids network |> String.concat ~sep:"; ") )
  in
  let%bind payload = find json log_entry [ "jsonPayload" ] in
  let%map event =
    if
      Result.ok (find bool payload [ "puppeteer_script_event" ])
      |> Option.value ~default:false
    then (
      let%bind msg =
        parse (parser_from_of_yojson Puppeteer_message.of_yojson) payload
      in
      [%log spam] "parsing puppeteer event, puppeteer_event_type = %s"
        (Option.value msg.puppeteer_event_type ~default:"<NONE>") ;
      Event_type.parse_puppeteer_event msg )
    else
      let%bind msg =
        parse (parser_from_of_yojson Logger.Message.of_yojson) payload
      in
      [%log spam] "parsing daemon structured event, event_id = %s"
        (Option.value
           (Option.( >>| ) msg.event_id Structured_log_events.string_of_id)
           ~default:"<NONE>" ) ;
      match msg.event_id with
      | Some _ ->
          Event_type.parse_daemon_event msg
      | None ->
          Event_type.parse_error_log msg
  in
  (node, event)

let rec poll_get_filtered_log_entries_node ~logger ~network ~event_writer
    ~last_log_index_seen node =
  let open Deferred.Let_syntax in
  if not (Pipe.is_closed event_writer) then
    match%bind
      Kubernetes_network.Node.get_filtered_log_entries ~logger
        ~last_log_index_seen node
    with
    | Ok log_entries ->
        List.iter log_entries ~f:(fun log_entry ->
            match
              log_entry |> Yojson.Safe.from_string
              |> parse_event_from_log_entry ~logger ~network
            with
            | Ok a ->
                Pipe.write_without_pushback_if_open event_writer a
            | Error e ->
                [%log warn] "Error parsing log $error"
                  ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ) ;
        let last_log_index_seen =
          List.length log_entries + last_log_index_seen
        in
        poll_get_filtered_log_entries_node ~logger ~network ~event_writer
          ~last_log_index_seen node
    | Error _ ->
        poll_get_filtered_log_entries_node ~logger ~network ~event_writer
          ~last_log_index_seen node
  else Deferred.Or_error.error_string "Event writer closed"

let rec poll_start_filtered_log_node ~log_filter ~logger ~network ~event_writer
    node =
  let open Deferred.Let_syntax in
  if not (Pipe.is_closed event_writer) then
    match%bind
      Kubernetes_network.Node.start_filtered_log ~logger ~log_filter node
    with
    | Ok () ->
        return (Ok ())
    | Error _ ->
        poll_start_filtered_log_node ~log_filter ~logger ~network ~event_writer
          node
  else Deferred.Or_error.error_string "Event writer closed"

let poll_node_for_logs_in_background ~log_filter ~logger ~network ~event_writer
    (node : Node.t) =
  let open Deferred.Or_error.Let_syntax in
  [%log info] "Requesting for $node to start its filtered logs"
    ~metadata:[ ("node", `String node.app_id) ] ;
  let%bind () =
    poll_start_filtered_log_node ~log_filter ~logger ~network ~event_writer node
  in
  [%log info] "$node has started its filtered logs. Beginning polling"
    ~metadata:[ ("node", `String node.app_id) ] ;
  poll_get_filtered_log_entries_node ~last_log_index_seen:0 ~logger ~network
    ~event_writer node

let poll_for_logs_in_background ~log_filter ~logger ~network ~event_writer =
  Kubernetes_network.all_pods network
  |> Core.String.Map.data
  |> Deferred.Or_error.List.iter ~how:`Parallel
       ~f:
         (poll_node_for_logs_in_background ~log_filter ~logger ~network
            ~event_writer )

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
  let { logger; event_reader = _; event_writer; background_job } = t in
  Pipe.close event_writer ;
  let%bind () = Deferred.map background_job ~f:(fun _ -> Ok ()) in
  [%log debug] "graphql polling log engine destroyed" ;
  return ()
