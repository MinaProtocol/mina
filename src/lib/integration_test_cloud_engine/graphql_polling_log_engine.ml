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
      [ "jsonPayload.level=(\"Warn\" OR \"Error\" OR \"Faulty_peer\" OR \
         \"Fatal\")"
      ]
  | From_daemon_log (struct_id, _) ->
      let filter =
        Printf.sprintf "jsonPayload.event_id=\"%s\""
          (Structured_log_events.string_of_id struct_id)
      in
      [ filter ]
  | From_puppeteer_log (id, _) ->
      let filter =
        Printf.sprintf "jsonPayload.puppeteer_event_type=\"%s\"" id
      in
      [ "jsonPayload.puppeteer_script_event=true"; filter ]

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
  [ disjunction ]

type t =
  { logger : Logger.t
  ; event_writer : (Node.t * Event_type.event) Pipe.Writer.t
  ; event_reader : (Node.t * Event_type.event) Pipe.Reader.t
  ; background_job : unit Deferred.t
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

let get_filtered_log_entries ~logger ~network ~last_log_index_seen =
  let open Deferred.Or_error.Let_syntax in
  let allpods = Kubernetes_network.all_pods network |> Core.String.Map.data in
  let logs =
    Deferred.Or_error.List.fold allpods ~init:[] ~f:(fun acc node ->
        let%bind node_logs =
          Kubernetes_network.Node.get_filtered_log_entries ~logger
            ~last_log_index_seen node
        in
        return (List.append acc node_logs) )
  in
  logs

let rec poll_get_filtered_log_entries ~last_log_index_seen ~logger ~network
    ~event_writer =
  if not (Pipe.is_closed event_writer) then (
    [%log spam] "Polling all testnet nodes for logs" ;
    let%bind log_entries =
      Deferred.map
        (get_filtered_log_entries ~logger ~network ~last_log_index_seen)
        ~f:Or_error.ok_exn
    in
    if List.length log_entries > 0 then
      [%log spam] "Parsing events from $n logs"
        ~metadata:[ ("n", `Int (List.length log_entries)) ]
    else [%log spam] "No logs were pulled" ;
    let%bind () =
      Deferred.List.iter ~how:`Sequential log_entries ~f:(fun log_entry ->
          ( match
              log_entry |> Yojson.Safe.from_string
              |> parse_event_from_log_entry ~logger ~network
            with
          | Ok a ->
              Pipe.write_without_pushback_if_open event_writer a
          | Error e ->
              [%log warn] "Error parsing log $error"
                ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ) ;
          Deferred.unit )
    in
    let%bind () = after (Time.Span.of_ms 10000.0) in
    let new_index = last_log_index_seen + List.length log_entries in
    poll_get_filtered_log_entries ~logger ~network ~event_writer
      ~last_log_index_seen:new_index )
  else Deferred.unit

let start_filtered_logs ~logger ~network ~log_filter =
  let allpods = Kubernetes_network.all_pods network |> Core.String.Map.data in
  Deferred.Or_error.List.iter ~how:`Parallel allpods ~f:(fun node ->
      Kubernetes_network.Node.start_filtered_log ~logger ~log_filter node )

let rec poll_start_filtered_log ~log_filter ~logger ~network =
  let open Deferred.Let_syntax in
  [%log info]
    "Polling all testnet nodes to get them to start their filtered logs" ;
  let%bind res = start_filtered_logs ~log_filter ~logger ~network in
  match res with
  | Ok () ->
      [%log info] "All nodes have started their filtered logs successfully" ;
      Deferred.return ()
  | Error _ ->
      poll_start_filtered_log ~log_filter ~logger ~network

let poll_for_logs_in_background ~log_filter ~logger ~network ~event_writer =
  [%log info] "Attempting to start the filtered log in all testnet nodes" ;
  let%bind () = poll_start_filtered_log ~log_filter ~logger ~network in
  [%log info]
    "Filtered logs in all testnet nodes successfully started.  Will now poll \
     for log entries" ;
  let%bind () =
    poll_get_filtered_log_entries ~logger ~network ~event_writer
      ~last_log_index_seen:0
  in
  [%log info] "poll_for_logs_in_background will now exit" ;
  Deferred.unit

let create ~logger ~(network : Kubernetes_network.t) =
  let open Deferred.Or_error.Let_syntax in
  let log_filter =
    let mina_container_filter = "resource.labels.container_name=\"mina\"" in
    let filters =
      [ network.testnet_log_filter; mina_container_filter ]
      @ all_event_types_log_filter
    in
    filters
  in
  let event_reader, event_writer = Pipe.create () in
  let background_job =
    poll_for_logs_in_background ~log_filter ~logger ~network ~event_writer
  in
  return { logger; event_reader; event_writer; background_job }

let destroy t : unit Deferred.Or_error.t =
  let open Deferred.Or_error.Let_syntax in
  let { logger; event_reader = _; event_writer; background_job } = t in
  Pipe.close event_writer ;
  let%bind () = Deferred.map background_job ~f:Or_error.return in
  [%log debug] "graphql polling log engine destroyed" ;
  return ()
