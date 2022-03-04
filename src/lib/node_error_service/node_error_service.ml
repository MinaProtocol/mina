open Async
open Core
open Pipe_lib
open Signature_lib

type catchup_job_states = Transition_frontier.Full_catchup_tree.job_states =
  { finished : int
  ; failed : int
  ; to_download : int
  ; to_initial_validate : int
  ; wait_for_parent : int
  ; to_verify : int
  ; to_build_breadcrumb : int
  }
[@@deriving to_yojson]

type node_error_data =
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
  ; catchup_job_states : catchup_job_states option
  ; sync_status : Sync_status.t
  ; block_height_at_best_tip : int option
  ; max_observed_block_height : int
  ; max_observed_unvalidated_block_height : int
  ; uptime_of_node : string
  }
[@@deriving to_yojson]

let send_node_error_data ~logger ~url node_error_data =
  let node_error_json = node_error_data_to_yojson node_error_data in
  let json = `Assoc [ ("data", node_error_json) ] in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  match%map
    Async.try_with (fun () ->
        Cohttp_async.Client.post ~headers
          ~body:(Yojson.Safe.to_string json |> Cohttp_async.Body.of_string)
          url)
  with
  | Ok ({ status; _ }, body) ->
      let metadata =
        [ ("data", node_error_json); ("url", `String (Uri.to_string url)) ]
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

let send_report ~logger ~node_error_url ~mina_ref ~error ~contact_info =
  match !mina_ref with
  | None ->
      [%log info] "Crashed before mina instance was created." ;
      Deferred.unit
  | Some mina ->
      let config = Mina_lib.config mina in
      let addrs_and_ports = config.gossip_net_params.addrs_and_ports in
      let peer_id =
        (Node_addrs_and_ports.to_peer_exn addrs_and_ports).peer_id
      in
      let ip_address =
        Node_addrs_and_ports.external_ip addrs_and_ports
        |> Core.Unix.Inet_addr.to_string
      in
      let commit_hash = Mina_version.commit_id in
      let git_branch = Mina_version.branch in
      let chain_id = config.chain_id in
      let public_key =
        let key_list =
          Mina_lib.block_production_pubkeys mina
          |> Public_key.Compressed.Set.to_list
        in
        if List.is_empty key_list then None else Some (List.hd_exn key_list)
      in
      let timestamp = Rfc3339_time.get_rfc3339_time () in
      let id = Uuid_unix.create () |> Uuid.to_string in
      let catchup_job_states =
        match
          Broadcast_pipe.Reader.peek @@ Mina_lib.transition_frontier mina
        with
        | None ->
            None
        | Some tf -> (
            match Transition_frontier.catchup_tree tf with
            | Full catchup_tree ->
                Some
                  (Transition_frontier.Full_catchup_tree.to_node_status_report
                     catchup_tree)
            | _ ->
                None )
      in
      let block_height_at_best_tip =
        Mina_lib.best_tip mina
        |> Participating_state.map
             ~f:Transition_frontier.Breadcrumb.blockchain_length
        |> Participating_state.map ~f:Unsigned.UInt32.to_int
        |> Participating_state.active
      in

      let sync_status =
        Mina_lib.sync_status mina |> Mina_incremental.Status.Observer.value_exn
      in
      let%bind hardware_info = Mina_lib.Conf_dir.get_hw_info () in
      send_node_error_data ~logger
        ~url:(Uri.of_string node_error_url)
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
        ; error = Error_json.error_to_yojson error
        ; catchup_job_states
        ; sync_status
        ; block_height_at_best_tip
        ; max_observed_block_height =
            !Mina_metrics.Transition_frontier.max_blocklength_observed
        ; max_observed_unvalidated_block_height =
            !Mina_metrics.Transition_frontier
             .max_unvalidated_blocklength_observed
        ; uptime_of_node =
            Time.(
              Span.to_string_hum
              @@ Time.diff (now ())
                   (Time_ns.to_time_float_round_nearest_microsecond
                      Mina_lib.daemon_start_time))
        }
