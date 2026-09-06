open Core
open Async
module HC = Mina_healthcheck_lib
module GC = Mina_graphql_client.Client
module Types = Mina_graphql_client.Types

let default_uri = "http://127.0.0.1:3085/graphql"

(* Swallow all Logger output.  stdout is reserved for the JSON envelope
   (or text answer) the user is asking for; without this override,
   [%log info] / [%log warn] calls inside [Mina_graphql_client] would
   mix log JSON with our answer and break pipe-friendly UX
   (e.g. [mina-healthcheck sync-status --json | jq]).  Real failures
   are propagated through the [Or_error] return value and printed by
   the CLI itself, so dropping log output here costs nothing.
   Registering a consumer for [Logger.Logger_id.mina] also stops the
   default lazy stdout consumer from being instantiated. *)
let () =
  Logger.Consumer_registry.register ~id:Logger.Logger_id.mina
    ~processor:(Logger.Processor.raw ())
    ~transport:(Logger.Transport.raw (fun _ -> ()))
    ()

let logger = Logger.create ()

let output json = print_endline (Yojson.Safe.pretty_to_string json)

let err_msg e = Error.to_string_hum e

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

(* One-shot CLI subcommands give the user an answer once and exit.
   Pass [~num_tries:1] so a dead or unreachable daemon produces a fast
   error instead of the 5-minute retry-and-sleep stretch baked into
   [exec_graphql_request]'s defaults — those defaults are tuned for
   long-running automation, not interactive CLI use.  Operators who
   actually want to wait on the daemon should use [wait]. *)
let one_shot_num_tries = 1

(* In [--json] mode, [Command.async_or_error] would print its own
   human-readable error to stderr on top of our JSON envelope, breaking
   pipe-friendly UX.  Bypass it by exiting directly. *)
let finish_json ~healthy =
  if healthy then Deferred.Or_error.return () else exit 1

let sync_status_command =
  Command.async_or_error
    ~summary:"Check sync status (exit 0 if SYNCED, exit 1 otherwise)"
    (let%map_open.Command uri = graphql_uri_flag and json = json_flag in
     fun () ->
       match%bind
         GC.get_sync_status ~num_tries:one_shot_num_tries ~logger (node_uri uri)
       with
       | Error e ->
           if json then (
             output
               (HC.sync_status_response_to_yojson
                  { healthy = false
                  ; sync_status = None
                  ; error = Some (err_msg e)
                  } ) ;
             exit 1 )
           else Deferred.Or_error.fail e
       | Ok status ->
           let is_synced = Sync_status.equal status `Synced in
           let s = String.uppercase (Sync_status.to_string status) in
           if json then (
             output
               (HC.sync_status_response_to_yojson
                  { healthy = is_synced; sync_status = Some s; error = None } ) ;
             finish_json ~healthy:is_synced )
           else (
             printf "%s\n" s ;
             if is_synced then Deferred.Or_error.return ()
             else Deferred.Or_error.errorf "node is not synced: %s" s ) )

let daemon_status_command =
  Command.async_or_error ~summary:"Get comprehensive daemon status"
    (let%map_open.Command uri = graphql_uri_flag and json = json_flag in
     fun () ->
       match%bind
         GC.get_daemon_status ~num_tries:one_shot_num_tries ~logger
           (node_uri uri)
       with
       | Error e ->
           if json then (
             output
               (HC.daemon_status_response_to_yojson
                  { healthy = false
                  ; sync_status = None
                  ; blockchain_length = None
                  ; highest_block_length_received = None
                  ; uptime_secs = None
                  ; state_hash = None
                  ; commit_id = None
                  ; peer_count = None
                  ; error = Some (err_msg e)
                  } ) ;
             exit 1 )
           else Deferred.Or_error.fail e
       | Ok ds ->
           ( if json then
             output
               (HC.daemon_status_response_to_yojson
                  { healthy = true
                  ; sync_status = Some ds.sync_status
                  ; blockchain_length = ds.blockchain_length
                  ; highest_block_length_received =
                      ds.highest_block_length_received
                  ; uptime_secs = ds.uptime_secs
                  ; state_hash = ds.state_hash
                  ; commit_id = ds.commit_id
                  ; peer_count = Some ds.peer_count
                  ; error = None
                  } )
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
       match%bind
         HC.check_peer_count ~num_tries:one_shot_num_tries ~logger
           (node_uri uri) ~min_peers
       with
       | Error e ->
           if json then (
             output
               (HC.peer_count_response_to_yojson
                  { healthy = false
                  ; peer_count = None
                  ; min_peers
                  ; error = Some (err_msg e)
                  } ) ;
             exit 1 )
           else Deferred.Or_error.fail e
       | Ok (healthy, count) ->
           if json then (
             output
               (HC.peer_count_response_to_yojson
                  { healthy; peer_count = Some count; min_peers; error = None } ) ;
             finish_json ~healthy )
           else (
             printf "%d peers (threshold: >= %d)\n" count min_peers ;
             if healthy then Deferred.Or_error.return ()
             else
               Deferred.Or_error.errorf "peer count %d is below minimum %d"
                 count min_peers ) )

let chain_length_command =
  Command.async_or_error
    ~summary:
      "Check if chain length matches highest received (exit 0 if matched)"
    (let%map_open.Command uri = graphql_uri_flag and json = json_flag in
     fun () ->
       match%bind
         HC.check_chain_length ~num_tries:one_shot_num_tries ~logger
           (node_uri uri)
       with
       | Error e ->
           if json then (
             output
               (HC.chain_length_response_to_yojson
                  { healthy = false
                  ; blockchain_length = None
                  ; highest_block_length_received = None
                  ; error = Some (err_msg e)
                  } ) ;
             exit 1 )
           else Deferred.Or_error.fail e
       | Ok (healthy, bl, hr) ->
           let fmt = Option.value_map ~default:"null" ~f:Int.to_string in
           if json then (
             output
               (HC.chain_length_response_to_yojson
                  { healthy
                  ; blockchain_length = bl
                  ; highest_block_length_received = hr
                  ; error = None
                  } ) ;
             finish_json ~healthy )
           else (
             printf "chain_length=%s highest_received=%s\n" (fmt bl) (fmt hr) ;
             if healthy then Deferred.Or_error.return ()
             else
               Deferred.Or_error.errorf
                 "chain length %s does not match highest received %s" (fmt bl)
                 (fmt hr) ) )

let readiness_envelope ~healthy ~error (r : Types.readiness option) :
    HC.readiness_response =
  match r with
  | Some r ->
      { healthy
      ; sync_status = Some r.sync_status
      ; peer_count = Some r.peer_count
      ; blockchain_length = r.blockchain_length
      ; highest_block_length_received = r.highest_block_length_received
      ; error
      }
  | None ->
      { healthy
      ; sync_status = None
      ; peer_count = None
      ; blockchain_length = None
      ; highest_block_length_received = None
      ; error
      }

let ready_command =
  Command.async_or_error
    ~summary:
      "Combined readiness check: synced + peers above threshold (exit 0 if \
       ready)"
    (let%map_open.Command uri = graphql_uri_flag
     and json = json_flag
     and min_peers = min_peers_flag in
     fun () ->
       match%bind
         GC.get_readiness ~num_tries:one_shot_num_tries ~logger (node_uri uri)
           ~min_peers
       with
       | Error e ->
           if json then (
             output
               (HC.readiness_response_to_yojson
                  (readiness_envelope ~healthy:false
                     ~error:(Some (err_msg e))
                     None ) ) ;
             exit 1 )
           else Deferred.Or_error.fail e
       | Ok r ->
           if json then (
             output
               (HC.readiness_response_to_yojson
                  (readiness_envelope ~healthy:r.ready ~error:None (Some r)) ) ;
             finish_json ~healthy:r.ready )
           else (
             if r.ready then print_endline "READY"
             else
               printf "NOT READY: %s\n"
                 (String.concat ~sep:", " (HC.readiness_problems ~min_peers r)) ;
             if r.ready then Deferred.Or_error.return ()
             else
               Deferred.Or_error.errorf "not ready: %s"
                 (String.concat ~sep:", " (HC.readiness_problems ~min_peers r))
             ) )

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
         ~doc:"SECONDS Maximum time to wait (default: 1200)"
         (optional_with_default 1200 int)
     and interval =
       flag "--interval" ~aliases:[ "-i" ]
         ~doc:"SECONDS Polling interval (default: 10)"
         (optional_with_default 10 int)
     in
     fun () ->
       match%bind
         HC.wait_for_ready ~quiet:json ~logger (node_uri uri) ~min_peers
           ~timeout ~interval
       with
       | Error e ->
           if json then (
             output
               (HC.readiness_response_to_yojson
                  (readiness_envelope ~healthy:false
                     ~error:(Some (err_msg e))
                     None ) ) ;
             exit 1 )
           else Deferred.Or_error.fail e
       | Ok r ->
           if json then
             output
               (HC.readiness_response_to_yojson
                  (readiness_envelope ~healthy:true ~error:None (Some r)) )
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
