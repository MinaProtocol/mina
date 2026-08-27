(* mina_archive_healthcheck.ml -- CLI for archive node health probes

   Every subcommand: run one query set, turn the answer into a
   [Report.t] with a pure evaluator, hand it to [emit]. *)

open Core
open Async
module Q = Archive_health_queries

let default_missing_blocks_width = 2000

(* "delay" throughout this CLI means archive-tip staleness:
   [now - latest_block_timestamp]. *)
let default_max_delay = 360

let default_max_missing = 10

let default_max_unparented = 5

let default_wait_timeout = 600

let default_wait_interval = 10

let default_server_host = "127.0.0.1"

(* Bound on a single TCP connect attempt; [wait] retries failed
   attempts on its own --interval. *)
let server_connect_timeout_sec = 5

let postgres_uri_env = "MINA_POSTGRES_URI"

(* Exit 2 (usage) rather than surfacing an opaque connection failure
   later. *)
let resolve_postgres_uri = function
  | Some uri ->
      uri
  | None -> (
      match Sys.getenv postgres_uri_env with
      | Some uri ->
          uri
      | None ->
          Stdlib.prerr_string
            (sprintf
               "error: no PostgreSQL URI given: pass --postgres-uri/-p or set \
                $%s\n"
               postgres_uri_env ) ;
          Stdlib.flush Stdlib.stderr ;
          Stdlib.exit 2 )

let postgres_uri_flag =
  Command.Param.(
    map
      (flag "--postgres-uri" ~aliases:[ "-p" ]
         ~doc:
           (sprintf
              "URI PostgreSQL connection URI (e.g., \
               postgres://user@localhost:5432/archive). Defaults to $%s."
              postgres_uri_env )
         (optional string) )
      ~f:resolve_postgres_uri )

let json_flag =
  Command.Param.(
    flag "--json" ~aliases:[ "-j" ] ~doc:" Output as JSON instead of text"
      no_arg )

let max_delay_flag =
  Command.Param.(
    flag "--max-delay"
      ~doc:
        (sprintf
           "SECONDS Maximum acceptable archive-tip staleness, i.e. (now - \
            latest block timestamp); fail if it exceeds this (default: %d)"
           default_max_delay )
      (optional_with_default default_max_delay int) )

let max_missing_flag =
  Command.Param.(
    flag "--max-missing"
      ~doc:
        (sprintf "N Maximum acceptable missing blocks (default: %d)"
           default_max_missing )
      (optional_with_default default_max_missing int) )

let max_unparented_flag =
  Command.Param.(
    flag "--max-unparented"
      ~doc:
        (sprintf "N Maximum acceptable unparented blocks (default: %d)"
           default_max_unparented )
      (optional_with_default default_max_unparented int) )

let server_host_flag =
  Command.Param.(
    flag "--server-host"
      ~doc:
        (sprintf "HOST Archive server host to probe (default: %s)"
           default_server_host )
      (optional_with_default default_server_host string) )

let missing_blocks_width_flag =
  Command.Param.(
    flag "--window"
      ~doc:
        (sprintf "N Block window for missing blocks check (default: %d)"
           default_missing_blocks_width )
      (optional_with_default default_missing_blocks_width int) )

(* [blocks.timestamp] is epoch milliseconds held as text (see
   create_schema.sql), so comparisons are in the same unit. *)
let now_ms () =
  Time_float.now () |> Time_float.to_span_since_epoch |> Time_float.Span.to_ms
  |> Int64.of_float

module Failure = struct
  (* Kept as a variant so the reason survives from where it is detected
     to where it is rendered: [wait] matches on it to build [Timed_out],
     and the JSON envelope renders it structurally. *)
  type t =
    | Db_unreachable of string
    | Db_query_failed of string
    | Server_unreachable of string
    | No_blocks
    | Invalid_timestamp of string
    | Thresholds_exceeded of string list
    | Timed_out of { after_seconds : int; last_failure : t option }
  [@@deriving sexp_of]

  (* Via [Error.t] so the JSON encoding matches the rest of the daemon's. *)
  let to_error t = Error.create_s (sexp_of_t t)

  let rec to_string = function
    | Db_unreachable message ->
        sprintf "Failed to connect to PostgreSQL: %s" message
    | Db_query_failed message ->
        sprintf "Archive query failed: %s" message
    | Server_unreachable message ->
        sprintf "Failed to connect to archive server: %s" message
    | No_blocks ->
        "no blocks in archive database"
    | Invalid_timestamp raw ->
        sprintf "invalid timestamp format: %s" raw
    | Thresholds_exceeded problems ->
        String.concat ~sep:", " problems
    | Timed_out { after_seconds; last_failure } ->
        let cause =
          match last_failure with
          | None ->
              ""
          | Some failure ->
              sprintf ": %s" (to_string failure)
        in
        sprintf "timed out after %ds%s" after_seconds cause
end

module Metrics = struct
  (* One constructor per probe, carrying only what that probe measures,
     so an envelope cannot claim a field the probe never read. *)
  type t =
    | Db_reachable
    | Server_reachable
    | Block_height of int
    | Recency of { delay_seconds : int64; max_delay : int }
    | Missing_blocks of
        { missing_blocks : int; max_missing : int; window : int }
    | Unparented_blocks of { unparented_blocks : int; max_unparented : int }
    | Readiness of
        { block_height : int
        ; delay_seconds : int64 option
        ; missing_blocks : int
        ; unparented_blocks : int
        }

  let int64_json n = `Intlit (Int64.to_string n)

  let optional_json_field name to_json = function
    | None ->
        []
    | Some value ->
        [ (name, to_json value) ]

  let to_json_fields = function
    | Db_reachable | Server_reachable ->
        []
    | Block_height height ->
        [ ("block_height", `Int height) ]
    | Recency { delay_seconds; max_delay } ->
        [ ("delay_seconds", int64_json delay_seconds)
        ; ("max_delay", `Int max_delay)
        ]
    | Missing_blocks { missing_blocks; max_missing; window } ->
        [ ("missing_blocks", `Int missing_blocks)
        ; ("max_missing", `Int max_missing)
        ; ("window", `Int window)
        ]
    | Unparented_blocks { unparented_blocks; max_unparented } ->
        [ ("unparented_blocks", `Int unparented_blocks)
        ; ("max_unparented", `Int max_unparented)
        ]
    | Readiness
        { block_height; delay_seconds; missing_blocks; unparented_blocks } ->
        [ ("block_height", `Int block_height) ]
        @ optional_json_field "delay_seconds" int64_json delay_seconds
        @ [ ("missing_blocks", `Int missing_blocks)
          ; ("unparented_blocks", `Int unparented_blocks)
          ]

  (* The text-mode line: what was measured, against which limit. The
     same line whether the probe passed or failed. *)
  let to_text = function
    | Db_reachable | Server_reachable ->
        "OK"
    | Block_height height ->
        Int.to_string height
    | Recency { delay_seconds; max_delay } ->
        sprintf "Last block: %Lds ago (max: %ds)" delay_seconds max_delay
    | Missing_blocks { missing_blocks; max_missing; window } ->
        sprintf "%d missing blocks (max: %d, window: %d)" missing_blocks
          max_missing window
    | Unparented_blocks { unparented_blocks; max_unparented } ->
        sprintf "%d unparented blocks (max: %d)" unparented_blocks
          max_unparented
    | Readiness
        { block_height; delay_seconds; missing_blocks; unparented_blocks } ->
        let delay =
          Option.value_map delay_seconds ~default:"n/a" ~f:(fun delay ->
              sprintf "%Lds" delay )
        in
        sprintf "height=%d delay=%s missing=%d unparented=%d" block_height delay
          missing_blocks unparented_blocks
end

type evaluation = Metrics.t option * (unit, Failure.t) Result.t

module Report = struct
  (* [kind] fixes the verdict key and the extra envelope fields, once,
     instead of at each print site. *)
  type kind = Probe | Readiness | Wait of { db_only : bool }

  type t =
    { kind : kind
    ; metrics : Metrics.t option  (** [None] when nothing was measured *)
    ; outcome : (unit, Failure.t) Result.t
    }

  let fail ~kind ?metrics failure = { kind; metrics; outcome = Error failure }

  let of_evaluation ~kind (metrics, outcome) = { kind; metrics; outcome }

  let passed t = Result.is_ok t.outcome

  (* The word a check is judged by: lower case as the JSON key, upper
     case as the text banner. *)
  let verdict_name = function
    | Probe ->
        "healthy"
    | Readiness | Wait _ ->
        "ready"

  let banner t =
    let name = String.uppercase (verdict_name t.kind) in
    if passed t then name else "NOT " ^ name

  let to_yojson ({ kind; metrics; outcome } as t) : Yojson.Safe.t =
    let failure = Result.error outcome in
    let verdict = [ (verdict_name kind, `Bool (passed t)) ] in
    let wait_flags =
      match kind with
      | Probe | Readiness ->
          []
      | Wait { db_only } ->
          let timed_out =
            match failure with
            | Some (Failure.Timed_out _) ->
                true
            | Some _ | None ->
                false
          in
          [ ("timed_out", `Bool timed_out); ("db_only", `Bool db_only) ]
    in
    let measured =
      Option.value_map metrics ~default:[] ~f:Metrics.to_json_fields
    in
    (* Only the combined probes list their breached thresholds; a
       single-signal probe has one, already implied by its metrics. *)
    let problems =
      match (kind, failure) with
      | (Readiness | Wait _), Some (Failure.Thresholds_exceeded problems) ->
          [ ( "problems"
            , `List (List.map problems ~f:(fun problem -> `String problem)) )
          ]
      | _ ->
          []
    in
    let error =
      Option.value_map failure ~default:[] ~f:(fun failure ->
          [ ("error", Error_json.error_to_yojson (Failure.to_error failure)) ] )
    in
    `Assoc (verdict @ wait_flags @ measured @ problems @ error)

  (* A single-signal probe reports what it measured, in both outcomes —
     the exit status carries the verdict.  The combined checks report
     the verdict, with the measurements after it when it is negative. *)
  let to_text ({ kind; metrics; outcome } as t) =
    match (kind, metrics) with
    | Probe, Some metrics ->
        Metrics.to_text metrics
    | (Readiness | Wait _), Some metrics ->
        if passed t then banner t
        else
          let failure =
            match outcome with
            | Ok () ->
                ""
            | Error failure ->
                sprintf " (%s)" (Failure.to_string failure)
          in
          sprintf "%s: %s%s" (banner t) (Metrics.to_text metrics) failure
    | _, None -> (
        match outcome with
        | Ok () ->
            banner t
        | Error failure ->
            Failure.to_string failure )
end

(* Diagnostics go to stderr through [Logger], which already renders
   JSON or plain text; stdout carries the probe result and nothing
   else, because k8s exec probes and [mina_automation] parse it as a
   single record. *)
let logger = Logger.create ~id:"mina-archive-healthcheck" ()

let setup_logging ~json =
  let processor =
    if json then Logger.Processor.raw ~log_level:Logger.Level.Info ()
    else
      Logger.Processor.pretty ~log_level:Logger.Level.Info
        ~config:
          { Interpolator_lib.Interpolator.mode = Inline
          ; max_interpolation_length = 50
          ; pretty_print = true
          }
  in
  Logger.Consumer_registry.register ~id:"mina-archive-healthcheck" ~processor
    ~transport:(Logger.Transport.raw Stdlib.prerr_endline)
    ()

(* The only place that writes probe output or sets the exit status, so
   the pass and fail paths cannot drift and a failure keeps the metrics
   it measured. *)
let emit ~json report =
  let channel = if Report.passed report then stdout else stderr in
  if json then
    print_endline (Yojson.Safe.pretty_to_string (Report.to_yojson report))
  else Out_channel.output_lines channel [ Report.to_text report ] ;
  Out_channel.flush stdout ;
  Out_channel.flush stderr ;
  if Report.passed report then Deferred.Or_error.return () else exit 1

(* Nothing above this point deals in [Caqti_error]. *)
let failure_of_caqti_call_error e = Failure.Db_query_failed (Caqti_error.show e)

let failure_of_caqti_load_error = function
  | `Load_rejected e ->
      Failure.Db_unreachable (Caqti_error.show (`Load_rejected e))
  | `Load_failed e ->
      Failure.Db_unreachable (Caqti_error.show (`Load_failed e))
  | _ ->
      Failure.Db_unreachable "database driver failed to load"

let failure_of_caqti_pool_error = function
  | `Connect_rejected e ->
      Failure.Db_unreachable (Caqti_error.show (`Connect_rejected e))
  | `Connect_failed e ->
      Failure.Db_unreachable (Caqti_error.show (`Connect_failed e))
  | `Post_connect e ->
      failure_of_caqti_call_error e
  | `Encode_rejected e ->
      Failure.Db_query_failed (Caqti_error.show (`Encode_rejected e))
  | `Encode_failed e ->
      Failure.Db_query_failed (Caqti_error.show (`Encode_failed e))
  | `Request_failed e ->
      Failure.Db_query_failed (Caqti_error.show (`Request_failed e))
  | `Decode_rejected e ->
      Failure.Db_query_failed (Caqti_error.show (`Decode_rejected e))
  | `Response_failed e ->
      Failure.Db_query_failed (Caqti_error.show (`Response_failed e))
  | `Response_rejected e ->
      Failure.Db_query_failed (Caqti_error.show (`Response_rejected e))
  | _ ->
      Failure.Db_query_failed "unknown database error"

let with_pool ~postgres_uri f =
  match Mina_caqti.connect_pool ~max_size:4 (Uri.of_string postgres_uri) with
  | Error e ->
      Deferred.return (Error (failure_of_caqti_load_error e))
  | Ok pool ->
      Mina_caqti.Pool.use f pool
      |> Deferred.map
           ~f:(Result.map_error ~f:(fun e -> failure_of_caqti_pool_error e))

(* The archive's client-facing RPC port.  A plain TCP connect proves
   the server is accepting connections — something no DB probe can
   see, because the schema answers queries before the archive process
   has started listening. *)
let probe_server ~host ~port =
  match%map
    Monitor.try_with (fun () ->
        Tcp.with_connection
          ~timeout:(Time_float.Span.of_int_sec server_connect_timeout_sec)
          (Tcp.Where_to_connect.of_host_and_port
             (Host_and_port.create ~host ~port) )
          (fun _socket _reader _writer -> Deferred.unit) )
  with
  | Ok () ->
      Ok ()
  | Error exn ->
      (* Render the errno as prose: raw OCaml exception syntax must not
         reach user-visible output (see the leak guard in tests/). *)
      let reason =
        match Monitor.extract_exn exn with
        | Unix.Unix_error (err, _, _) ->
            Unix.Error.message err
        | exn ->
            Exn.to_string_mach exn
      in
      Error (Failure.Server_unreachable (sprintf "%s:%d: %s" host port reason))

let evaluation_of_result ~evaluate : (_, Failure.t) Result.t -> evaluation =
  function
  | Ok answer ->
      evaluate answer
  | Error failure ->
      (None, Error failure)

let probe ~postgres_uri ~kind ~evaluate query =
  let%map result = with_pool ~postgres_uri query in
  Report.of_evaluation ~kind (evaluation_of_result ~evaluate result)

let readiness_query ~window db =
  let open Deferred.Result.Let_syntax in
  let%bind block_height = Q.Max_block_height.run db () in
  let%bind latest_ts = Q.Latest_block_timestamp.run db () in
  let%bind missing_blocks =
    Q.Missing_blocks_count.run db ~missing_blocks_width:window ()
  in
  let%map unparented_blocks = Q.Unparented_blocks_count.run db () in
  (block_height, latest_ts, missing_blocks, unparented_blocks)

(* Evaluators: pure, one per probe, so the threshold rules read on
   their own. *)

let threshold_failure problems : (unit, Failure.t) Result.t =
  if List.is_empty problems then Ok ()
  else Error (Failure.Thresholds_exceeded problems)

let evaluate_db_ready (_ : int) : evaluation = (Some Metrics.Db_reachable, Ok ())

let evaluate_block_height height : evaluation =
  (Some (Metrics.Block_height height), Ok ())

(* A tip dated ahead of wall clock yields a negative delay; callers
   treat that as a failure, not as an extremely fresh block. *)
let delay_of_timestamp ~now latest_ts =
  match latest_ts with
  | None ->
      Error Failure.No_blocks
  | Some raw -> (
      match Option.try_with (fun () -> Int64.of_string raw) with
      | None ->
          Error (Failure.Invalid_timestamp raw)
      | Some ts_ms ->
          Ok (Int64.( / ) (Int64.( - ) now ts_ms) 1000L, Int64.( > ) ts_ms now)
      )

let recency_status ~now ~max_delay latest_ts =
  match delay_of_timestamp ~now latest_ts with
  | Error failure ->
      (None, [ Failure.to_string failure ], Some failure)
  | Ok (delay_seconds, in_future) ->
      let problems =
        if in_future then [ "latest block timestamp is in the future" ]
        else if Int64.( > ) delay_seconds (Int64.of_int max_delay) then
          [ sprintf "block delay %Lds > %ds" delay_seconds max_delay ]
        else []
      in
      (Some delay_seconds, problems, None)

let evaluate_recency ~now ~max_delay latest_ts : evaluation =
  match recency_status ~now ~max_delay latest_ts with
  | None, _, Some failure ->
      (None, Error failure)
  | Some delay_seconds, problems, _ ->
      ( Some (Metrics.Recency { delay_seconds; max_delay })
      , threshold_failure problems )
  | None, problems, None ->
      (None, threshold_failure problems)

let evaluate_missing_blocks ~max_missing ~window missing_blocks : evaluation =
  let problems =
    if missing_blocks > max_missing then
      [ sprintf "missing blocks %d > %d" missing_blocks max_missing ]
    else []
  in
  ( Some (Metrics.Missing_blocks { missing_blocks; max_missing; window })
  , threshold_failure problems )

let evaluate_unparented_blocks ~max_unparented unparented_blocks : evaluation =
  let problems =
    if unparented_blocks > max_unparented then
      [ sprintf "unparented blocks %d > %d" unparented_blocks max_unparented ]
    else []
  in
  ( Some (Metrics.Unparented_blocks { unparented_blocks; max_unparented })
  , threshold_failure problems )

(* Every signal is evaluated, so the report lists all breached
   thresholds rather than only the first. *)
let evaluate_readiness ~now ~max_delay ~max_missing ~max_unparented
    (block_height, latest_ts, missing_blocks, unparented_blocks) : evaluation =
  let delay_seconds, recency_problems, _ =
    recency_status ~now ~max_delay latest_ts
  in
  let problems =
    recency_problems
    @ ( if missing_blocks > max_missing then
          [ sprintf "missing blocks %d > %d" missing_blocks max_missing ]
        else [] )
    @
    if unparented_blocks > max_unparented then
      [ sprintf "unparented blocks %d > %d" unparented_blocks max_unparented ]
    else []
  in
  ( Some
      (Metrics.Readiness
         { block_height; delay_seconds; missing_blocks; unparented_blocks } )
  , threshold_failure problems )

let db_ready_command =
  Command.async_or_error
    ~summary:"Check if archive database is reachable (exit 0 if connected)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag in
     fun () ->
       setup_logging ~json ;
       let%bind report =
         probe ~postgres_uri ~kind:Report.Probe ~evaluate:evaluate_db_ready
           (fun db -> Q.Max_block_height.run db () )
       in
       emit ~json report )

let block_height_command =
  Command.async_or_error
    ~summary:"Report the maximum block height in the archive database"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag in
     fun () ->
       setup_logging ~json ;
       let%bind report =
         probe ~postgres_uri ~kind:Report.Probe ~evaluate:evaluate_block_height
           (fun db -> Q.Max_block_height.run db () )
       in
       emit ~json report )

let block_recency_command =
  Command.async_or_error
    ~summary:
      "Check if latest block is recent enough (exit 0 if within --max-delay \
       seconds)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_delay = max_delay_flag in
     fun () ->
       setup_logging ~json ;
       let%bind report =
         probe ~postgres_uri ~kind:Report.Probe
           ~evaluate:(fun latest_ts ->
             evaluate_recency ~now:(now_ms ()) ~max_delay latest_ts )
           (fun db -> Q.Latest_block_timestamp.run db ())
       in
       emit ~json report )

let missing_blocks_command =
  Command.async_or_error
    ~summary:
      "Check missing blocks count in sliding window (exit 0 if within \
       threshold)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_missing = max_missing_flag
     and window = missing_blocks_width_flag in
     fun () ->
       setup_logging ~json ;
       let%bind report =
         probe ~postgres_uri ~kind:Report.Probe
           ~evaluate:(evaluate_missing_blocks ~max_missing ~window) (fun db ->
             Q.Missing_blocks_count.run db ~missing_blocks_width:window () )
       in
       emit ~json report )

let unparented_blocks_command =
  Command.async_or_error
    ~summary:
      "Check unparented (orphan) blocks count (exit 0 if within threshold)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_unparented = max_unparented_flag in
     fun () ->
       setup_logging ~json ;
       let%bind report =
         probe ~postgres_uri ~kind:Report.Probe
           ~evaluate:(evaluate_unparented_blocks ~max_unparented) (fun db ->
             Q.Unparented_blocks_count.run db () )
       in
       emit ~json report )

let ready_command =
  Command.async_or_error
    ~summary:
      "Combined readiness: db reachable + recent block + missing/unparented \
       within thresholds"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_delay = max_delay_flag
     and max_missing = max_missing_flag
     and max_unparented = max_unparented_flag
     and window = missing_blocks_width_flag in
     fun () ->
       setup_logging ~json ;
       let%bind report =
         probe ~postgres_uri ~kind:Report.Readiness
           ~evaluate:(fun answer ->
             evaluate_readiness ~now:(now_ms ()) ~max_delay ~max_missing
               ~max_unparented answer )
           (readiness_query ~window)
       in
       emit ~json report )

let server_ready_command =
  Command.async_or_error
    ~summary:
      "Check if the archive server accepts TCP connections (exit 0 if \
       connected)"
    (let%map_open.Command json = json_flag
     and host = server_host_flag
     and port =
       flag "--server-port" ~doc:"PORT Archive server port to probe (e.g. 3086)"
         (required int)
     in
     fun () ->
       setup_logging ~json ;
       let%bind outcome = probe_server ~host ~port in
       let metrics =
         match outcome with
         | Ok () ->
             Some Metrics.Server_reachable
         | Error _ ->
             None
       in
       emit ~json (Report.of_evaluation ~kind:Report.Probe (metrics, outcome))
    )

(* Both wait modes share this loop; they differ only in [attempt]. On
   expiry the last failure is wrapped in [Timed_out]. *)
let rec poll ~start ~deadline ~interval ~kind attempt =
  let elapsed () =
    Float.to_int
      (Time_float.Span.to_sec (Time_float.diff (Time_float.now ()) start))
  in
  let%bind metrics, outcome = attempt () in
  match outcome with
  | Ok () ->
      return (Report.of_evaluation ~kind (metrics, Ok ()))
  | Error failure ->
      if Time_float.( >= ) (Time_float.now ()) deadline then
        return
          (Report.fail ~kind ?metrics
             (Failure.Timed_out
                { after_seconds = elapsed (); last_failure = Some failure } ) )
      else (
        [%log info] "archive not ready after $elapsed_seconds s: $reason"
          ~metadata:
            [ ("elapsed_seconds", `Int (elapsed ()))
            ; ("reason", `String (Failure.to_string failure))
            ; ( "measured"
              , Option.value_map metrics ~default:`Null ~f:(fun metrics ->
                    `Assoc (Metrics.to_json_fields metrics) ) )
            ] ;
        let%bind () = after (Time_float.Span.of_int_sec interval) in
        poll ~start ~deadline ~interval ~kind attempt )

let wait_command =
  Command.async_or_error
    ~summary:"Block until archive passes readiness checks or timeout expires"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_delay = max_delay_flag
     and max_missing = max_missing_flag
     and max_unparented = max_unparented_flag
     and window = missing_blocks_width_flag
     and timeout =
       flag "--timeout" ~aliases:[ "-t" ]
         ~doc:
           (sprintf "SECONDS Maximum time to wait (default: %d)"
              default_wait_timeout )
         (optional_with_default default_wait_timeout int)
     and interval =
       flag "--interval" ~aliases:[ "-i" ]
         ~doc:
           (sprintf "SECONDS Polling interval (default: %d)"
              default_wait_interval )
         (optional_with_default default_wait_interval int)
     and db_only =
       flag "--db-only"
         ~doc:
           " Wait only for the archive DB to respond; skip the recency / \
            missing / unparented checks.  Useful as an init-container or 'is \
            the archive process up at all' gate, where you want to block until \
            the schema is queryable but cannot wait for ingestion (e.g. a \
            freshly-initialized DB with no blocks yet)."
         no_arg
     and server_host = server_host_flag
     and server_port =
       flag "--server-port"
         ~doc:
           "PORT Also require the archive server to accept a TCP connection on \
            this port before reporting ready.  The DB probes cannot see the \
            server: the schema answers queries before the archive process \
            starts listening, so a block sent then is silently lost."
         (optional int)
     in
     fun () ->
       setup_logging ~json ;
       let kind = Report.Wait { db_only } in
       let start = Time_float.now () in
       let deadline =
         Time_float.add start (Time_float.Span.of_int_sec timeout)
       in
       (* One pool for every poll, not one per iteration. *)
       match
         Mina_caqti.connect_pool ~max_size:4 (Uri.of_string postgres_uri)
       with
       | Error e ->
           emit ~json (Report.fail ~kind (failure_of_caqti_load_error e))
       | Ok pool ->
           let run query =
             Mina_caqti.Pool.use query pool
             |> Deferred.map
                  ~f:
                    (Result.map_error ~f:(fun e ->
                         failure_of_caqti_pool_error e ) )
           in
           (* [--db-only] waits only for the [blocks] table to answer:
              the full check needs a non-empty table and so can never
              pass against a freshly-bootstrapped archive. *)
           let attempt () =
             if db_only then
               run (fun db -> Q.Max_block_height.run db ())
               |> Deferred.map
                    ~f:(evaluation_of_result ~evaluate:evaluate_db_ready)
             else
               run (readiness_query ~window)
               |> Deferred.map
                    ~f:
                      (evaluation_of_result ~evaluate:(fun answer ->
                           evaluate_readiness ~now:(now_ms ()) ~max_delay
                             ~max_missing ~max_unparented answer ) )
           in
           (* Server first: it is the cheaper probe, and until it
              listens the DB answer alone would falsely report ready. *)
           let gated_attempt () =
             match server_port with
             | None ->
                 attempt ()
             | Some port -> (
                 match%bind probe_server ~host:server_host ~port with
                 | Ok () ->
                     attempt ()
                 | Error failure ->
                     return (None, Error failure) )
           in
           let%bind report =
             poll ~start ~deadline ~interval ~kind gated_attempt
           in
           emit ~json report )

let () =
  Command_unix.run
    (Command.group
       ~summary:
         "Mina archive healthcheck CLI — lightweight probe commands for \
          archive node monitoring"
       [ ("db-ready", db_ready_command)
       ; ("server-ready", server_ready_command)
       ; ("block-height", block_height_command)
       ; ("block-recency", block_recency_command)
       ; ("missing-blocks", missing_blocks_command)
       ; ("unparented-blocks", unparented_blocks_command)
       ; ("ready", ready_command)
       ; ("wait", wait_command)
       ] )
