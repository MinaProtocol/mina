(* rosetta_healthcheck.ml — slim CLI for Mina Rosetta health probes.

   This binary focuses exclusively on readiness and recency checks.
   Generic Rosetta API calls live in the sibling [rosetta-client] binary
   so operators don't have to choose between two overlapping CLIs for
   debugging.  HTTP calls here go through [Rosetta_client] so
   network_identifier handling, timeout enforcement, and error formatting
   stay in one place. *)

open Core_kernel
open Async
module MRC = Rosetta_client
module RM = MRC.Models

(* Operators can set [MINA_ROSETTA_URI] to avoid passing --online-uri on
   every invocation; --online-uri still overrides it when given.  Shared with
   the sibling rosetta-client binary. *)
let rosetta_uri_env_var = "MINA_ROSETTA_URI"

let default_online_uri =
  Option.value (Sys.getenv rosetta_uri_env_var) ~default:"http://localhost:3087"

let default_network = "testnet"

let default_blockchain = "mina"

let default_max_age = 360

let default_timeout = 600

let default_interval = 10

let default_http_timeout_secs = 5.0

(* ---------- CLI flag helpers ---------- *)

let online_uri_flag =
  Command.Param.(
    flag "--online-uri" ~aliases:[ "-o" ]
      ~doc:
        (sprintf
           "URI Rosetta online base URL (default: %s, overridable via $%s)"
           default_online_uri rosetta_uri_env_var )
      (optional_with_default default_online_uri string))

let network_flag =
  Command.Param.(
    flag "--network" ~aliases:[ "-n" ]
      ~doc:
        (sprintf "NAME network_identifier.network (default: %s)" default_network)
      (optional_with_default default_network string))

let blockchain_flag =
  Command.Param.(
    flag "--blockchain"
      ~doc:
        (sprintf "NAME network_identifier.blockchain (default: %s)"
           default_blockchain )
      (optional_with_default default_blockchain string))

let json_flag =
  Command.Param.(
    flag "--json" ~aliases:[ "-j" ] ~doc:" Output as JSON instead of text"
      no_arg)

let max_age_flag =
  Command.Param.(
    flag "--max-age"
      ~doc:
        (sprintf "SECONDS Maximum acceptable age of current tip (default: %d)"
           default_max_age )
      (optional_with_default default_max_age int))

let timeout_flag ~default =
  Command.Param.(
    flag "--timeout" ~aliases:[ "-t" ]
      ~doc:(sprintf "SECONDS Max seconds to wait (default: %d)" default)
      (optional_with_default default int))

let interval_flag =
  Command.Param.(
    flag "--interval" ~aliases:[ "-i" ]
      ~doc:(sprintf "SECONDS Polling interval (default: %d)" default_interval)
      (optional_with_default default_interval int))

(* ---------- I/O helpers ---------- *)

(* Emit a JSON record to stdout.  We bypass Async's own [print_*]
   wrappers (which use non-blocking writers that may not flush before
   a subsequent [Stdlib.exit]) by going straight to [Stdlib.stdout],
   and flush explicitly so the record appears even when we exit without
   going through Async's shutdown path. *)
let output json =
  Stdlib.print_string (Yojson.Safe.pretty_to_string json) ;
  Stdlib.print_newline () ;
  Stdlib.flush Stdlib.stdout

let make_client ~online_uri ~blockchain ~network =
  MRC.Http.create ~base_uri:(Uri.of_string online_uri) ~blockchain ~network
    ~timeout:default_http_timeout_secs ()

(* Emit either the success path or a single JSON error record.  Mirrors
   the contract in [mina_archive_healthcheck]: in [json] mode, never
   double-print — emit exactly one JSON record and [exit 1] on failure;
   in text mode, hand the error back to the [async_or_error] wrapper. *)
let finish ~json ~json_error result =
  match result with
  | Ok () ->
      Deferred.Or_error.return ()
  | Error e ->
      if json then (
        output (json_error e) ;
        Stdlib.exit 1 )
      else Deferred.Or_error.fail e

let network_identifier_pair (network_identifier : RM.Network_identifier.t) =
  ( network_identifier.RM.Network_identifier.blockchain
  , network_identifier.RM.Network_identifier.network )

let block_height_json h = `Intlit (Int64.to_string h)

(* Now-time as epoch seconds. *)
let now_secs () = Time.now () |> Time.to_span_since_epoch |> Time.Span.to_sec

let age_seconds_from_timestamp_ms ts =
  let now_ms = Int64.of_float (now_secs () *. 1000.0) in
  let age_ms = Int64.( - ) now_ms ts in
  let age_secs = Int64.( / ) age_ms 1000L in
  if Int64.( < ) age_secs 0L then 0L else age_secs

(* ---------- connectivity (was: network-list) ---------- *)

let connectivity_probe client ~expected_blockchain ~expected_network =
  match%map MRC.Data.network_list_response client with
  | Error e ->
      Error e
  | Ok response ->
      let advertised =
        List.map response.RM.Network_list_response.network_identifiers
          ~f:network_identifier_pair
      in
      if List.is_empty advertised then
        Or_error.error_string "/network/list returned no network_identifiers"
      else
        let match_found =
          List.exists advertised ~f:(fun (b, n) ->
              String.equal b expected_blockchain
              && String.equal n expected_network )
        in
        if match_found then Ok advertised
        else
          let adv_str =
            List.map advertised ~f:(fun (b, n) -> sprintf "%s:%s" b n)
            |> String.concat ~sep:", "
          in
          Or_error.errorf "expected network %s:%s not advertised (got: %s)"
            expected_blockchain expected_network adv_str

let connectivity_command =
  Command.async_or_error
    ~summary:
      "Verify Rosetta's /network/list advertises the expected network.  Lists \
       the advertised set when the expected network is absent."
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       let%bind result =
         connectivity_probe client ~expected_blockchain:blockchain
           ~expected_network:network
       in
       let json_error e =
         `Assoc
           [ ("healthy", `Bool false)
           ; ("error", `String (Error.to_string_hum e))
           ]
       in
       let inner =
         match result with
         | Error e ->
             Error e
         | Ok advertised ->
             let adv_json =
               `List
                 (List.map advertised ~f:(fun (b, n) ->
                      `Assoc
                        [ ("blockchain", `String b); ("network", `String n) ] )
                 )
             in
             if json then
               output
                 (`Assoc
                   [ ("healthy", `Bool true)
                   ; ("expected_network", `String network)
                   ; ("advertised", adv_json)
                   ] )
             else
               printf "advertises %d networks (contains %s)\n"
                 (List.length advertised) network ;
             Ok ()
       in
       finish ~json ~json_error inner )

(* ---------- tip-recency (was: network-status) ---------- *)

let tip_recency_probe client = MRC.Data.network_status_response client

let tip_recency_command =
  Command.async_or_error
    ~summary:
      "POST /network/status — exit 0 if tip is returned and its timestamp is \
       within --max-age"
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag
     and max_age = max_age_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       let%bind result = tip_recency_probe client in
       let json_error e =
         `Assoc
           [ ("healthy", `Bool false)
           ; ("error", `String (Error.to_string_hum e))
           ]
       in
       let inner =
         match result with
         | Error e ->
             Error e
         | Ok response ->
             let tip =
               response.RM.Network_status_response.current_block_identifier
             in
             let idx = tip.RM.Block_identifier.index in
             let h = tip.RM.Block_identifier.hash in
             let d =
               age_seconds_from_timestamp_ms
                 response.RM.Network_status_response.current_block_timestamp
             in
             if Int64.( <= ) d (Int64.of_int max_age) then (
               if json then
                 output
                   (`Assoc
                     [ ("healthy", `Bool true)
                     ; ("block_height", block_height_json idx)
                     ; ("block_hash", `String h)
                     ; ("age_seconds", `Intlit (Int64.to_string d))
                     ] )
               else printf "tip height=%Ld hash=%s age=%Lds\n" idx h d ;
               Ok () )
             else
               let err_msg =
                 sprintf "tip is %Ld seconds old, exceeds max age %d" d max_age
               in
               if json then (
                 output
                   (`Assoc
                     [ ("healthy", `Bool false)
                     ; ("block_height", block_height_json idx)
                     ; ("block_hash", `String h)
                     ; ("age_seconds", `Intlit (Int64.to_string d))
                     ; ("max_age", `Int max_age)
                     ; ("error", `String err_msg)
                     ] ) ;
                 Stdlib.exit 1 )
               else (
                 printf "tip is %Ld seconds old, exceeds max %d\n" d max_age ;
                 Error (Error.of_string err_msg) )
       in
       finish ~json ~json_error inner )

(* ---------- Composite: [ready] and [wait] ---------- *)

(* Runs the three low-cost probes and collects problems.  When
   [max_age] is set, the recency check on network-status is part of
   the decision; otherwise we only require that the endpoint returned
   a tip. *)
let run_ready_checks client ~expected_blockchain ~expected_network ~max_age =
  let open Deferred.Let_syntax in
  let problems = ref [] in
  let add p = problems := p :: !problems in
  let%bind list_ok =
    match%map
      connectivity_probe client ~expected_blockchain ~expected_network
    with
    | Ok _ ->
        true
    | Error e ->
        add (sprintf "connectivity: %s" (Error.to_string_hum e)) ;
        false
  in
  let%bind status_ok, height_opt, age_opt =
    match%map MRC.Data.network_status_response client with
    | Error e ->
        add (sprintf "tip-recency: %s" (Error.to_string_hum e)) ;
        (false, None, None)
    | Ok response ->
        let tip =
          response.RM.Network_status_response.current_block_identifier
        in
        let idx = tip.RM.Block_identifier.index in
        let age =
          age_seconds_from_timestamp_ms
            response.RM.Network_status_response.current_block_timestamp
        in
        let recent = Int64.( <= ) age (Int64.of_int max_age) in
        if not recent then
          add (sprintf "tip-recency: tip age %Lds > %ds" age max_age) ;
        (recent, Some idx, Some age)
  in
  let%map options_ok =
    match%map MRC.Data.network_options_response client with
    | Error e ->
        add (sprintf "network-options: %s" (Error.to_string_hum e)) ;
        false
    | Ok response ->
        let version = response.RM.Network_options_response.version in
        let allow = response.RM.Network_options_response.allow in
        let rosetta_version = version.RM.Version.rosetta_version in
        let operation_types = allow.RM.Allow.operation_types in
        let ok =
          (not (String.is_empty rosetta_version))
          && not (List.is_empty operation_types)
        in
        if not ok then
          add "network-options: missing rosetta_version or operation_types" ;
        ok
  in
  let ready = list_ok && status_ok && options_ok in
  (ready, height_opt, age_opt, List.rev !problems)

let ready_command =
  Command.async_or_error
    ~summary:
      "Composite readiness: connectivity + tip-recency + /network/options"
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag
     and max_age = max_age_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       let%bind ready, height_opt, age_opt, problems =
         run_ready_checks client ~expected_blockchain:blockchain
           ~expected_network:network ~max_age
       in
       (* [run_ready_checks] always returns a plain tuple: transport
          errors from each probe are captured as entries in [problems]
          rather than as an [Error] channel.  So we never get a
          short-circuit error to forward here — the decision is simply
          ready vs. not-ready, formatted for text or JSON. *)
       if ready then (
         if json then
           output
             (`Assoc
               ( [ ("ready", `Bool true) ]
               @ Option.value_map height_opt ~default:[] ~f:(fun h ->
                     [ ("block_height", block_height_json h) ] )
               @ Option.value_map age_opt ~default:[] ~f:(fun d ->
                     [ ("age_seconds", `Intlit (Int64.to_string d)) ] ) ) )
         else print_endline "READY" ;
         Deferred.Or_error.return () )
       else
         let err_msg =
           sprintf "not ready: %s" (String.concat ~sep:", " problems)
         in
         if json then (
           output
             (`Assoc
               ( [ ("ready", `Bool false)
                 ; ( "problems"
                   , `List (List.map problems ~f:(fun p -> `String p)) )
                 ; ("error", `String err_msg)
                 ]
               @ Option.value_map height_opt ~default:[] ~f:(fun h ->
                     [ ("block_height", block_height_json h) ] )
               @ Option.value_map age_opt ~default:[] ~f:(fun d ->
                     [ ("age_seconds", `Intlit (Int64.to_string d)) ] ) ) ) ;
           Stdlib.exit 1 )
         else (
           printf "NOT READY: %s\n" (String.concat ~sep:", " problems) ;
           Deferred.Or_error.error_string err_msg ) )

let wait_command =
  Command.async_or_error
    ~summary:"Block until Rosetta passes readiness checks or timeout expires"
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag
     and max_age = max_age_flag
     and timeout = timeout_flag ~default:default_timeout
     and interval = interval_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       let start = Time.now () in
       let deadline = Time.add start (Time.Span.of_int_sec timeout) in
       let timed_out () = Time.( >= ) (Time.now ()) deadline in
       let elapsed () =
         Float.to_int (Time.Span.to_sec (Time.diff (Time.now ()) start))
       in
       let rec loop () =
         let%bind ready, height_opt, age_opt, problems =
           run_ready_checks client ~expected_blockchain:blockchain
             ~expected_network:network ~max_age
         in
         if ready then (
           if json then
             output
               (`Assoc
                 ( [ ("ready", `Bool true) ]
                 @ Option.value_map height_opt ~default:[] ~f:(fun h ->
                       [ ("block_height", block_height_json h) ] )
                 @ Option.value_map age_opt ~default:[] ~f:(fun d ->
                       [ ("age_seconds", `Intlit (Int64.to_string d)) ] ) ) )
           else print_endline "READY" ;
           Deferred.Or_error.return () )
         else if timed_out () then
           if json then (
             output
               (`Assoc
                 ( [ ("ready", `Bool false)
                   ; ("timed_out", `Bool true)
                   ; ( "problems"
                     , `List (List.map problems ~f:(fun p -> `String p)) )
                   ]
                 @ Option.value_map height_opt ~default:[] ~f:(fun h ->
                       [ ("block_height", block_height_json h) ] )
                 @ Option.value_map age_opt ~default:[] ~f:(fun d ->
                       [ ("age_seconds", `Intlit (Int64.to_string d)) ] ) ) ) ;
             Stdlib.exit 1 )
           else
             Deferred.Or_error.errorf "timed out waiting for readiness: %s"
               (String.concat ~sep:", " problems)
         else (
           eprintf "[%3ds] not ready: %s\n" (elapsed ())
             (String.concat ~sep:", " problems) ;
           let%bind () = after (Time.Span.of_int_sec interval) in
           loop () )
       in
       loop () )

let () =
  Command.run
    (Command.group
       ~summary:
         "Mina Rosetta healthcheck CLI — readiness and recency probes. For \
          generic Rosetta API calls use 'rosetta-client'."
       [ ("ready", ready_command)
       ; ("wait", wait_command)
       ; ("tip-recency", tip_recency_command)
       ; ("connectivity", connectivity_command)
       ] )
