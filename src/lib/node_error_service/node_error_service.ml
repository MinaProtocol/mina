open Async
open Core
open Signature_lib

(* needs to be kept in sync with the constant in minaprotocol/mina-deployments:src/node-status-error-system-backend/node_error/src/index.js *)
let max_report_bytes = 10_000

type node_state =
  { peer_id : string
  ; ip_address : string
  ; chain_id : string
  ; public_key : Public_key.Compressed.t option
  ; catchup_job_states : Transition_frontier.Full_catchup_tree.job_states option
  ; block_height_at_best_tip : int option
  ; sync_status : Sync_status.t
  ; hardware_info : string list option
  ; uptime_of_node : string
  }

type node_error_report =
  { version : int
  ; peer_id : string
  ; ip_address : string
  ; public_key : Public_key.Compressed.t option
  ; git_branch : string
  ; commit_hash : string
  ; chain_id : string
  ; contact_info : string option
  ; hardware_info : string list option
  ; timestamp : string
  ; id : string
  ; error : Yojson.Safe.t
  ; catchup_job_states : Transition_frontier.Full_catchup_tree.job_states option
  ; sync_status : Sync_status.t
  ; block_height_at_best_tip : int option
  ; max_observed_block_height : int
  ; max_observed_unvalidated_block_height : int
  ; uptime_of_node : string
  }
[@@deriving to_yojson]

type config =
  { get_node_state : unit -> node_state option Deferred.t
  ; node_error_url : Uri.t
  ; contact_info : string option
  }

let config = ref None

let set_config ~get_node_state ~node_error_url ~contact_info =
  if Option.is_some !config then
    failwith "Node_error_service.set_config called more than once"
  else config := Some { get_node_state; node_error_url; contact_info }

let serialize_report report =
  `Assoc [ ("data", node_error_report_to_yojson report) ]

let send_node_error_report ~logger ~url report =
  let json = serialize_report report in
  let json_string = Yojson.Safe.to_string json in
  (* TODO: move length check to to send_node_error_data *)
  if String.length json_string > max_report_bytes then (
    [%log error]
      "Could not send error report because generated error exceeded max report \
       size" ;
    Deferred.unit )
  else
    let headers =
      Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
    in
    match%map
      Async.try_with (fun () ->
          Cohttp_async.Client.post ~headers
            ~body:(Cohttp_async.Body.of_string json_string)
            url )
    with
    | Ok ({ status; _ }, body) ->
        let metadata =
          [ ("data", json); ("url", `String (Uri.to_string url)) ]
        in
        if Cohttp.Code.code_of_status status = 200 then
          [%log info] "Sent node error data to URL $url" ~metadata
        else
          let extra_metadata =
            match body with
            | `String s ->
                [ ("error", `String s) ]
            | `Strings ss ->
                [ ("error", `List (List.map ss ~f:(fun s -> `String s))) ]
            | `Empty | `Pipe _ ->
                []
          in
          [%log error] "Failed to send node error data to URL $url"
            ~metadata:(metadata @ extra_metadata)
    | Error e ->
        [%log error] "Failed to send node error data to URL $url"
          ~metadata:
            [ ("error", `String (Exn.to_string e))
            ; ("url", `String (Uri.to_string url))
            ]

let with_deps ~logger ~f =
  match !config with
  | None ->
      [%log error]
        "Could not send error report: Node_error_service was not configured" ;
      Deferred.unit
  | Some { get_node_state; node_error_url; contact_info } -> (
      match%bind get_node_state () with
      | None ->
          [%log info]
            "Could not send error report: mina instance has not been created \
             yet." ;
          Deferred.unit
      | Some node_state ->
          f ~node_state ~node_error_url ~contact_info )

let generate_report ~node_state ~contact_info error =
  let commit_hash = Mina_version.commit_id in
  let git_branch = Mina_version.branch in
  let timestamp = Rfc3339_time.get_rfc3339_time () in
  let id = Uuid_unix.create () |> Uuid.to_string in
  let ({ peer_id
       ; ip_address
       ; public_key
       ; chain_id
       ; hardware_info
       ; catchup_job_states
       ; sync_status
       ; block_height_at_best_tip
       ; uptime_of_node
       }
        : node_state ) =
    node_state
  in
  Some
    { version = 1
    ; peer_id
    ; ip_address
    ; public_key
    ; git_branch
    ; commit_hash
    ; chain_id
    ; contact_info
    ; hardware_info
    ; timestamp
    ; id
    ; error
    ; catchup_job_states
    ; sync_status
    ; block_height_at_best_tip
    ; max_observed_block_height =
        !Mina_metrics.Transition_frontier.max_blocklength_observed
    ; max_observed_unvalidated_block_height =
        !Mina_metrics.Transition_frontier.max_unvalidated_blocklength_observed
    ; uptime_of_node
    }

let send_dynamic_report ~logger ~generate_error =
  with_deps ~logger ~f:(fun ~node_state ~node_error_url ~contact_info ->
      match generate_report ~node_state ~contact_info (`String "") with
      | None ->
          Deferred.unit
      | Some base_report ->
          (* subtract 2 bytes for the size of empty string in json *)
          let base_report_size =
            String.length (Yojson.Safe.to_string @@ serialize_report base_report)
            - 2
          in
          let available_bytes = max_report_bytes - base_report_size in
          let report =
            { base_report with error = generate_error available_bytes }
          in
          send_node_error_report ~logger ~url:node_error_url report )

let send_report ~logger ~error =
  with_deps ~logger ~f:(fun ~node_state ~node_error_url ~contact_info ->
      match
        generate_report ~node_state ~contact_info
          (Error_json.error_to_yojson error)
      with
      | None ->
          Deferred.unit
      | Some report ->
          send_node_error_report ~logger ~url:node_error_url report )
