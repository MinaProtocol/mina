open Core
open Async
module HC = Mina_healthcheck_lib
module Types = Mina_graphql_client.Types

let default_uri = "http://127.0.0.1:3085/graphql"

let logger = Logger.create ()

let output json = print_endline (Yojson.Safe.pretty_to_string json)

let output_error e =
  output
    (HC.error_response_to_yojson
       { healthy = false; error = Error.to_string_hum e } )

let graphql_uri_flag =
  Command.Param.(
    flag "--graphql-uri" ~aliases:[ "-u" ]
      ~doc:(sprintf "URI GraphQL endpoint (default: %s)" default_uri)
      (optional_with_default default_uri string))

let json_flag =
  Command.Param.(
    flag "--json" ~aliases:[ "-j" ] ~doc:" Output as JSON instead of text"
      no_arg)

let min_peers_flag =
  Command.Param.(
    flag "--min-peers" ~aliases:[ "-n" ]
      ~doc:"N Minimum peer count threshold (default: 2)"
      (optional_with_default 2 int))

let node_uri s = Uri.of_string s

let sync_status_command =
  Command.async_or_error
    ~summary:"Check sync status (exit 0 if SYNCED, exit 1 otherwise)"
    (let%map_open.Command uri = graphql_uri_flag and json = json_flag in
     fun () ->
       match%bind HC.get_sync_status ~logger (node_uri uri) with
       | Error e ->
           if json then output_error e ;
           Deferred.Or_error.fail e
       | Ok status ->
           let is_synced = Sync_status.equal status `Synced in
           let s = String.uppercase (Sync_status.to_string status) in
           if json then
             output
               (HC.sync_status_response_to_yojson
                  { healthy = is_synced; sync_status = s } )
           else printf "%s\n" s ;
           if is_synced then Deferred.Or_error.return ()
           else Deferred.Or_error.errorf "node is not synced: %s" s )

let daemon_status_command =
  Command.async_or_error ~summary:"Get comprehensive daemon status"
    (let%map_open.Command uri = graphql_uri_flag and json = json_flag in
     fun () ->
       match%bind HC.get_daemon_status ~logger (node_uri uri) with
       | Error e ->
           if json then output_error e ;
           Deferred.Or_error.fail e
       | Ok ds ->
           ( if json then output (Types.daemon_status_to_yojson ds)
           else
             let opt s = Option.value ~default:"n/a" s in
             let opt_int n =
               Option.value_map ~default:"n/a" ~f:Int.to_string n
             in
             printf "Sync status:       %s\n"
               (Sync_status.to_string ds.sync_status) ;
             printf "Blockchain length: %s\n" (opt_int ds.blockchain_length) ;
             printf "Highest received:  %s\n"
               (opt_int ds.highest_block_length_received) ;
             printf "Uptime:            %s\n"
               (Option.value_map ~default:"n/a"
                  ~f:(fun s -> sprintf "%ds" s)
                  ds.uptime_secs ) ;
             printf "State hash:        %s\n" (opt ds.state_hash) ;
             printf "Commit ID:         %s\n" (opt ds.commit_id) ;
             printf "Peers:             %d\n" ds.peer_count ) ;
           Deferred.Or_error.return () )

let peer_count_command =
  Command.async_or_error
    ~summary:
      "Check peer count against threshold (exit 0 if at or above, exit 1 \
       otherwise)"
    (let%map_open.Command uri = graphql_uri_flag
     and json = json_flag
     and min_peers = min_peers_flag in
     fun () ->
       match%bind HC.check_peer_count ~logger (node_uri uri) ~min_peers with
       | Error e ->
           if json then output_error e ;
           Deferred.Or_error.fail e
       | Ok (healthy, count) ->
           if json then
             output
               (HC.peer_count_response_to_yojson
                  { healthy; peer_count = count; min_peers } )
           else printf "%d peers (threshold: >= %d)\n" count min_peers ;
           if healthy then Deferred.Or_error.return ()
           else
             Deferred.Or_error.errorf "peer count %d is below minimum %d" count
               min_peers )

let chain_length_command =
  Command.async_or_error
    ~summary:
      "Check if chain length matches highest received (exit 0 if matched)"
    (let%map_open.Command uri = graphql_uri_flag and json = json_flag in
     fun () ->
       match%bind HC.check_chain_length ~logger (node_uri uri) with
       | Error e ->
           if json then output_error e ;
           Deferred.Or_error.fail e
       | Ok (healthy, bl, hr) ->
           let fmt = Option.value_map ~default:"null" ~f:Int.to_string in
           if json then
             output
               (HC.chain_length_response_to_yojson
                  { healthy
                  ; blockchain_length = bl
                  ; highest_block_length_received = hr
                  } )
           else printf "chain_length=%s highest_received=%s\n" (fmt bl) (fmt hr) ;
           if healthy then Deferred.Or_error.return ()
           else
             Deferred.Or_error.errorf
               "chain length %s does not match highest received %s" (fmt bl)
               (fmt hr) )

let ready_command =
  Command.async_or_error
    ~summary:
      "Combined readiness check: synced + peers above threshold (exit 0 if \
       ready)"
    (let%map_open.Command uri = graphql_uri_flag
     and json = json_flag
     and min_peers = min_peers_flag in
     fun () ->
       match%bind HC.check_readiness ~logger (node_uri uri) ~min_peers with
       | Error e ->
           if json then output_error e ;
           Deferred.Or_error.fail e
       | Ok r ->
           if json then output (Types.readiness_to_yojson r)
           else if r.ready then print_endline "READY"
           else
             printf "NOT READY: %s\n"
               (String.concat ~sep:", " (HC.readiness_problems ~min_peers r)) ;
           if r.ready then Deferred.Or_error.return ()
           else
             Deferred.Or_error.errorf "not ready: %s"
               (String.concat ~sep:", " (HC.readiness_problems ~min_peers r)) )

let wait_command =
  Command.async_or_error
    ~summary:
      "Block until node passes readiness checks (synced + peers + chain caught \
       up)"
    (let%map_open.Command uri = graphql_uri_flag
     and json = json_flag
     and min_peers = min_peers_flag
     and timeout =
       flag "--timeout" ~aliases:[ "-t" ]
         ~doc:"SECONDS Maximum time to wait (default: 600)"
         (optional_with_default 600 int)
     and interval =
       flag "--interval" ~aliases:[ "-i" ]
         ~doc:"SECONDS Polling interval (default: 10)"
         (optional_with_default 10 int)
     in
     fun () ->
       match%bind
         HC.wait_for_ready ~logger (node_uri uri) ~min_peers ~timeout ~interval
       with
       | Error e ->
           if json then output_error e ;
           Deferred.Or_error.fail e
       | Ok r ->
           if json then output (Types.readiness_to_yojson r)
           else print_endline "READY" ;
           Deferred.Or_error.return () )

let () =
  Command.run
    (Command.group
       ~summary:
         "Mina daemon healthcheck CLI — lightweight probe commands for \
          Kubernetes, Docker, and monitoring"
       [ ("sync-status", sync_status_command)
       ; ("daemon-status", daemon_status_command)
       ; ("peer-count", peer_count_command)
       ; ("chain-length", chain_length_command)
       ; ("ready", ready_command)
       ; ("wait", wait_command)
       ] )
