open Async
open Core
open Pipe_lib

type catchup_job_states =
  (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list option
[@@deriving to_yojson]

type node_status_data =
  { block_height_at_best_tip : int
  ; max_observed_block_height : int
  ; max_observed_unvalidated_block_height : int
  ; catchup_job_states : catchup_job_states
  ; sync_status : Sync_status.Stable.V1.t
  ; libp2p_input_bandwidth : float
  ; libp2p_output_bandwidth : float
  }
[@@deriving to_yojson]

let send_node_status_data ~logger ~url node_status_data =
  let node_status_json = node_status_data_to_yojson node_status_data in
  let json = `Assoc [ ("data", node_status_json) ] in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  match%map
    Cohttp_async.Client.post ~headers
      ~body:(Yojson.Safe.to_string json |> Cohttp_async.Body.of_string)
      url
  with
  | { status; _ }, body ->
      let metadata =
        [ ("data", node_status_json); ("url", `String (Uri.to_string url)) ]
      in
      if Cohttp.Code.code_of_status status = 200 then
        [%log info] "Sent node status data to URL $url" ~metadata
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
        [%log error] "Failed to send node status data to URL $url"
          ~metadata:(metadata @ extra_metadata)

let start ~logger ~node_status_url ~transition_frontier ~sync_status ~network =
  let url_string = Option.value ~default:"127.0.0.1" node_status_url in
  [%log info] "Starting node status service using URL $url"
    ~metadata:[ ("URL", `String url_string) ] ;

  let _data = Prometheus.CollectorRegistry.(collect default) in
  don't_wait_for
  @@
  match Broadcast_pipe.Reader.peek transition_frontier with
  | None ->
      [%log info] "Transition frontier not available for node status service" ;
      Deferred.unit
  | Some tf -> (
      let catchup_job_states =
        match Transition_frontier.catchup_tree tf with
        | Full catchup_tree ->
            Some
              (Transition_frontier.Full_catchup_tree.to_node_status_report
                 catchup_tree)
        | _ ->
            None
      in
      let sync_status =
        sync_status |> Mina_incremental.Status.Observer.value_exn
      in
      match%bind Mina_networking.bandwidth_info network with
      | Ok (libp2p_input_bandwidth, libp2p_output_bandwidth) ->
          let node_status_data =
            { block_height_at_best_tip = 1
            ; max_observed_block_height = 2
            ; max_observed_unvalidated_block_height = 3
            ; catchup_job_states
            ; sync_status
            ; libp2p_input_bandwidth
            ; libp2p_output_bandwidth
            }
          in
          send_node_status_data ~logger ~url:(Uri.of_string url_string)
            node_status_data
      | Error e ->
          [%log info]
            ~metadata:[ ("error", `String (Error.to_string_hum e)) ]
            "Failed to get bandwidth info from libp2p" ;
          Deferred.unit )
