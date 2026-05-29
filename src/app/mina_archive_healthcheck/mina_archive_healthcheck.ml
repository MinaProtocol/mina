(* mina_archive_healthcheck.ml -- CLI for archive node health probes *)

open Core_kernel
open Async
module Q = Archive_health_queries

let default_missing_blocks_width = 2000

let default_max_delay = 360

let default_max_missing = 10

let default_max_unparented = 5

let postgres_uri_env = "MINA_POSTGRES_URI"

(* Resolve the connection URI from [--postgres-uri] if given, otherwise
   fall back to the [MINA_POSTGRES_URI] environment variable.  Exits
   with code 2 (usage error) if neither is provided, rather than
   surfacing an opaque connection failure later. *)
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
      ~f:resolve_postgres_uri)

let json_flag =
  Command.Param.(
    flag "--json" ~aliases:[ "-j" ] ~doc:" Output as JSON instead of text"
      no_arg)

let max_delay_flag =
  Command.Param.(
    flag "--max-delay"
      ~doc:
        (sprintf
           "SECONDS Maximum acceptable delay since last block (default: %d)"
           default_max_delay )
      (optional_with_default default_max_delay int))

let max_missing_flag =
  Command.Param.(
    flag "--max-missing"
      ~doc:
        (sprintf "N Maximum acceptable missing blocks (default: %d)"
           default_max_missing )
      (optional_with_default default_max_missing int))

let max_unparented_flag =
  Command.Param.(
    flag "--max-unparented"
      ~doc:
        (sprintf "N Maximum acceptable unparented blocks (default: %d)"
           default_max_unparented )
      (optional_with_default default_max_unparented int))

let missing_blocks_width_flag =
  Command.Param.(
    flag "--window"
      ~doc:
        (sprintf "N Block window for missing blocks check (default: %d)"
           default_missing_blocks_width )
      (optional_with_default default_missing_blocks_width int))

(* Emit one JSON record on stdout and flush immediately.  The explicit
   flush matters because several failure paths follow [output] with a
   hard [Stdlib.exit]: under Async, relying on the at-exit flush can
   drop the buffered write, so we flush while the fd is still in a known
   state. *)
let output json =
  print_endline (Yojson.Safe.pretty_to_string json) ;
  Out_channel.flush Out_channel.stdout

(* Print a final text line and exit non-zero.  Used by the
   threshold-failure paths so they report a single human-readable line
   and set exit status without ALSO returning an error to the
   [async_or_error] wrapper (which would print a second ["Error: ..."]
   line). *)
let fail_text fmt =
  ksprintf
    (fun s ->
      print_string s ;
      Out_channel.flush Out_channel.stdout ;
      Stdlib.exit 1 )
    fmt

(* Typed model for every JSON envelope emitted by the subcommands.

   Previously each command hand-rolled its own [`Assoc [...]] list,
   duplicating the same keys ("healthy"/"error"/"block_height"/…)
   across success, threshold-failure and connect-failure paths.  A
   single deriving record removes that duplication: a command builds
   the value it wants from [empty] (via record-update) and serializes
   it with one [to_yojson].

   Every field is optional with [@default None] so it is omitted from
   the rendered object when left unset — preserving the prior shape
   where each envelope carried only its relevant keys.  [int64] fields
   render as bare JSON number literals, matching the prior [`Intlit]
   encoding. *)
module Output = struct
  type t =
    { healthy : bool option [@default None]
    ; ready : bool option [@default None]
    ; timed_out : bool option [@default None]
    ; db_only : bool option [@default None]
    ; block_height : int option [@default None]
    ; delay_seconds : int64 option [@default None]
    ; max_delay : int option [@default None]
    ; missing_blocks : int option [@default None]
    ; max_missing : int option [@default None]
    ; unparented_blocks : int option [@default None]
    ; max_unparented : int option [@default None]
    ; window : int option [@default None]
    ; problems : string list option [@default None]
    ; error : string option [@default None]
    }
  [@@deriving to_yojson]

  let empty =
    { healthy = None
    ; ready = None
    ; timed_out = None
    ; db_only = None
    ; block_height = None
    ; delay_seconds = None
    ; max_delay = None
    ; missing_blocks = None
    ; max_missing = None
    ; unparented_blocks = None
    ; max_unparented = None
    ; window = None
    ; problems = None
    ; error = None
    }

  let to_json = to_yojson
end

(* The [json_error] callback for every [healthy]-keyed subcommand is
   identical — render [{healthy=false; error}].  [ready]/[wait] key the
   same failure as [{ready=false; error}] instead. *)
let health_error e =
  Output.(
    to_json
      { empty with healthy = Some false; error = Some (Error.to_string_hum e) })

let readiness_error e =
  Output.(
    to_json
      { empty with ready = Some false; error = Some (Error.to_string_hum e) })

let with_pool ~postgres_uri f =
  let uri = Uri.of_string postgres_uri in
  match Mina_caqti.connect_pool ~max_size:4 uri with
  | Error e ->
      let msg =
        sprintf "Failed to connect to PostgreSQL: %s" (Caqti_error.show e)
      in
      Deferred.Or_error.fail (Error.of_string msg)
  | Ok pool ->
      Mina_caqti.Pool.use f pool
      |> Deferred.map
           ~f:
             (Result.map_error ~f:(fun e ->
                  Error.of_string (Caqti_error.show e) ) )

(* Run a subcommand body for an error path where nothing has been
   printed yet (e.g. DB connect failure, query error).  In [json]
   mode, emits exactly one JSON record via [json_error] on stdout and
   exits 1 directly — this avoids the [async_or_error] wrapper
   printing an extra plain-text ["Error: ..."] line on stderr, which
   would otherwise produce mixed-format output for machine consumers.
   In text mode we keep the previous behavior and return the error so
   the wrapper prints the message.

   Callers MUST NOT have already emitted any JSON on stdout before
   invoking [finish] in [json] mode — otherwise the invocation would
   produce two JSON records on stdout.  Threshold-failure paths that
   want to include their metric fields alongside the error should
   instead emit a single merged JSON directly and [exit 1], bypassing
   [finish] (see e.g. [block_recency_command]). *)
let finish ~json ~json_error result =
  match result with
  | Ok () ->
      Deferred.Or_error.return ()
  | Error e ->
      if json then (
        output (json_error e) ;
        exit 1 )
      else Deferred.Or_error.fail e

(* Current wall-clock time as epoch milliseconds. The archive
   [blocks.timestamp] column stores the block timestamp as a string
   representation of epoch milliseconds (see create_schema.sql:
   "timestamp text NOT NULL"), so comparisons are in the same unit. *)
let now_ms () =
  Time.now () |> Time.to_span_since_epoch |> Time.Span.to_ms |> Int64.of_float

let db_ready_command =
  Command.async_or_error
    ~summary:"Check if archive database is reachable (exit 0 if connected)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag in
     fun () ->
       let%bind result =
         with_pool ~postgres_uri (fun db -> Q.Max_block_height.run db ())
       in
       finish ~json ~json_error:health_error
         ( match result with
         | Ok _height ->
             if json then
               output Output.(to_json { empty with healthy = Some true })
             else printf "OK\n" ;
             Ok ()
         | Error e ->
             Error e ) )

let block_height_command =
  Command.async_or_error
    ~summary:"Report the maximum block height in the archive database"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag in
     fun () ->
       let%bind result =
         with_pool ~postgres_uri (fun db -> Q.Max_block_height.run db ())
       in
       finish ~json ~json_error:health_error
         ( match result with
         | Ok height ->
             if json then
               output
                 Output.(
                   to_json
                     { empty with
                       healthy = Some true
                     ; block_height = Some height
                     })
             else printf "%d\n" height ;
             Ok ()
         | Error e ->
             Error e ) )

let block_recency_command =
  Command.async_or_error
    ~summary:
      "Check if latest block is recent enough (exit 0 if within --max-delay \
       seconds)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_delay = max_delay_flag in
     fun () ->
       let%bind result =
         with_pool ~postgres_uri (fun db -> Q.Latest_block_timestamp.run db ())
       in
       let inner =
         match result with
         | Error e ->
             Error e
         | Ok None ->
             Error (Error.of_string "no blocks in archive database")
         | Ok (Some ts_str) -> (
             match Option.try_with (fun () -> Int64.of_string ts_str) with
             | None ->
                 Error
                   (Error.of_string
                      (sprintf "invalid timestamp format: %s" ts_str) )
             | Some ts_ms ->
                 let delay_secs =
                   Int64.( / ) (Int64.( - ) (now_ms ()) ts_ms) 1000L
                 in
                 let healthy =
                   Int64.( <= ) delay_secs (Int64.of_int max_delay)
                 in
                 if healthy then (
                   if json then
                     output
                       Output.(
                         to_json
                           { empty with
                             healthy = Some true
                           ; delay_seconds = Some delay_secs
                           ; max_delay = Some max_delay
                           })
                   else
                     printf "Last block: %Lds ago (max: %ds)\n" delay_secs
                       max_delay ;
                   Ok () )
                 else
                   let err_msg =
                     sprintf
                       "latest block is %Ld seconds old, exceeds max delay %d"
                       delay_secs max_delay
                   in
                   if json then (
                     output
                       Output.(
                         to_json
                           { empty with
                             healthy = Some false
                           ; delay_seconds = Some delay_secs
                           ; max_delay = Some max_delay
                           ; error = Some err_msg
                           }) ;
                     Stdlib.exit 1 )
                   else
                     fail_text "Last block: %Lds ago (max: %ds)\n" delay_secs
                       max_delay )
       in
       finish ~json ~json_error:health_error inner )

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
       let%bind result =
         with_pool ~postgres_uri (fun db ->
             Q.Missing_blocks_count.run db ~missing_blocks_width:window () )
       in
       let inner =
         match result with
         | Error e ->
             Error e
         | Ok count ->
             let healthy = count <= max_missing in
             if healthy then (
               if json then
                 output
                   Output.(
                     to_json
                       { empty with
                         healthy = Some true
                       ; missing_blocks = Some count
                       ; max_missing = Some max_missing
                       ; window = Some window
                       })
               else
                 printf "%d missing blocks (max: %d, window: %d)\n" count
                   max_missing window ;
               Ok () )
             else
               let err_msg =
                 sprintf "missing blocks count %d exceeds threshold %d" count
                   max_missing
               in
               if json then (
                 output
                   Output.(
                     to_json
                       { empty with
                         healthy = Some false
                       ; missing_blocks = Some count
                       ; max_missing = Some max_missing
                       ; window = Some window
                       ; error = Some err_msg
                       }) ;
                 Stdlib.exit 1 )
               else
                 fail_text "%d missing blocks (max: %d, window: %d)\n" count
                   max_missing window
       in
       finish ~json ~json_error:health_error inner )

let unparented_blocks_command =
  Command.async_or_error
    ~summary:
      "Check unparented (orphan) blocks count (exit 0 if within threshold)"
    (let%map_open.Command postgres_uri = postgres_uri_flag
     and json = json_flag
     and max_unparented = max_unparented_flag in
     fun () ->
       let%bind result =
         with_pool ~postgres_uri (fun db -> Q.Unparented_blocks_count.run db ())
       in
       let inner =
         match result with
         | Error e ->
             Error e
         | Ok count ->
             let healthy = count <= max_unparented in
             if healthy then (
               if json then
                 output
                   Output.(
                     to_json
                       { empty with
                         healthy = Some true
                       ; unparented_blocks = Some count
                       ; max_unparented = Some max_unparented
                       })
               else
                 printf "%d unparented blocks (max: %d)\n" count max_unparented ;
               Ok () )
             else
               let err_msg =
                 sprintf "unparented blocks count %d exceeds threshold %d" count
                   max_unparented
               in
               if json then (
                 output
                   Output.(
                     to_json
                       { empty with
                         healthy = Some false
                       ; unparented_blocks = Some count
                       ; max_unparented = Some max_unparented
                       ; error = Some err_msg
                       }) ;
                 Stdlib.exit 1 )
               else
                 fail_text "%d unparented blocks (max: %d)\n" count
                   max_unparented
       in
       finish ~json ~json_error:health_error inner )

(* Evaluate readiness from the four underlying metrics. Returns the
   [(ready, delay_secs, problems)] triple. [latest_ts] is the raw
   [text]-typed timestamp from the [blocks] table, which we interpret
   as epoch milliseconds (see [now_ms] above). *)
let evaluate_readiness ~latest_ts ~missing ~unparented ~max_delay ~max_missing
    ~max_unparented =
  let future_ts, delay_secs =
    match latest_ts with
    | None ->
        (false, Int64.max_value)
    | Some ts_str -> (
        match Option.try_with (fun () -> Int64.of_string ts_str) with
        | None ->
            (false, Int64.max_value)
        | Some ts_ms ->
            let now = now_ms () in
            let delay_secs = Int64.( / ) (Int64.( - ) now ts_ms) 1000L in
            (Int64.( > ) ts_ms now, delay_secs) )
  in
  let recent =
    (not future_ts) && Int64.( <= ) delay_secs (Int64.of_int max_delay)
  in
  let missing_ok = missing <= max_missing in
  let unparented_ok = unparented <= max_unparented in
  let ready = recent && missing_ok && unparented_ok in
  let problems = ref [] in
  if not recent then
    problems :=
      ( if future_ts then "latest block timestamp is in the future"
      else sprintf "block delay %Lds > %ds" delay_secs max_delay )
      :: !problems ;
  if not missing_ok then
    problems :=
      sprintf "missing blocks %d > %d" missing max_missing :: !problems ;
  if not unparented_ok then
    problems :=
      sprintf "unparented blocks %d > %d" unparented max_unparented :: !problems ;
  (ready, delay_secs, List.rev !problems)

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
       let%bind result =
         with_pool ~postgres_uri (fun db ->
             let open Deferred.Result.Let_syntax in
             let%bind height = Q.Max_block_height.run db () in
             let%bind latest_ts = Q.Latest_block_timestamp.run db () in
             let%bind missing =
               Q.Missing_blocks_count.run db ~missing_blocks_width:window ()
             in
             let%bind unparented = Q.Unparented_blocks_count.run db () in
             return (height, latest_ts, missing, unparented) )
       in
       let inner =
         match result with
         | Error e ->
             Error e
         | Ok (height, latest_ts, missing, unparented) ->
             let ready, delay_secs, problems =
               evaluate_readiness ~latest_ts ~missing ~unparented ~max_delay
                 ~max_missing ~max_unparented
             in
             if ready then (
               if json then
                 output
                   Output.(
                     to_json
                       { empty with
                         ready = Some true
                       ; block_height = Some height
                       ; delay_seconds = Some delay_secs
                       ; missing_blocks = Some missing
                       ; unparented_blocks = Some unparented
                       })
               else print_endline "READY" ;
               Ok () )
             else
               let err_msg =
                 sprintf "not ready: %s" (String.concat ~sep:", " problems)
               in
               if json then (
                 output
                   Output.(
                     to_json
                       { empty with
                         ready = Some false
                       ; block_height = Some height
                       ; delay_seconds = Some delay_secs
                       ; missing_blocks = Some missing
                       ; unparented_blocks = Some unparented
                       ; problems = Some problems
                       ; error = Some err_msg
                       }) ;
                 Stdlib.exit 1 )
               else
                 fail_text "NOT READY: %s\n" (String.concat ~sep:", " problems)
       in
       finish ~json ~json_error:readiness_error inner )

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
         ~doc:"SECONDS Maximum time to wait (default: 600)"
         (optional_with_default 600 int)
     and interval =
       flag "--interval" ~aliases:[ "-i" ]
         ~doc:"SECONDS Polling interval (default: 10)"
         (optional_with_default 10 int)
     and db_only =
       flag "--db-only"
         ~doc:
           " Wait only for the archive DB to respond; skip the recency / \
            missing / unparented checks.  Useful as an init-container or 'is \
            the archive process up at all' gate, where you want to block until \
            the schema is queryable but cannot wait for ingestion (e.g. a \
            freshly-initialized DB with no blocks yet)."
         no_arg
     in
     fun () ->
       (* Connect the pool once up front and reuse it across every
          poll.  Previously every iteration called [with_pool], which
          opened a brand new Caqti pool — wasteful and noisy for
          long-running waits. *)
       let uri = Uri.of_string postgres_uri in
       match Mina_caqti.connect_pool ~max_size:4 uri with
       | Error e ->
           let err =
             Error.of_string
               (sprintf "Failed to connect to PostgreSQL: %s"
                  (Caqti_error.show e) )
           in
           if json then (
             output
               Output.(
                 to_json
                   { empty with
                     ready = Some false
                   ; timed_out = Some false
                   ; db_only = Some db_only
                   ; error = Some (Error.to_string_hum err)
                   }) ;
             exit 1 )
           else Deferred.Or_error.fail err
       | Ok pool ->
           let start = Time.now () in
           let deadline = Time.add start (Time.Span.of_int_sec timeout) in
           let timed_out () = Time.( >= ) (Time.now ()) deadline in
           let elapsed () =
             Float.to_int (Time.Span.to_sec (Time.diff (Time.now ()) start))
           in
           let use f =
             Mina_caqti.Pool.use f pool
             |> Deferred.map
                  ~f:
                    (Result.map_error ~f:(fun e ->
                         Error.of_string (Caqti_error.show e) ) )
           in
           (* In [--db-only] mode we deliberately skip recency / missing
              / unparented checks: the only signal we wait for is "the
              [blocks] table responds to a [SELECT MAX(height)]."  This
              exists because the full readiness check requires a
              non-None [latest_ts] and so cannot succeed against a
              freshly-bootstrapped, empty archive.  See the README for
              the full rationale. *)
           let rec db_only_loop () =
             match%bind use (fun db -> Q.Max_block_height.run db ()) with
             | Ok _height ->
                 if json then
                   output
                     Output.(
                       to_json
                         { empty with ready = Some true; db_only = Some true })
                 else print_endline "READY (db-only)" ;
                 Deferred.Or_error.return ()
             | Error e when timed_out () ->
                 if json then (
                   output
                     Output.(
                       to_json
                         { empty with
                           ready = Some false
                         ; timed_out = Some true
                         ; db_only = Some true
                         ; error = Some (Error.to_string_hum e)
                         }) ;
                   exit 1 )
                 else
                   Deferred.Or_error.errorf "timed out waiting for DB: %s"
                     (Error.to_string_hum e)
             | Error e ->
                 eprintf "[%3ds] DB unreachable: %s\n" (elapsed ())
                   (Error.to_string_hum e) ;
                 let%bind () = after (Time.Span.of_int_sec interval) in
                 db_only_loop ()
           in
           let rec loop () =
             match%bind
               use (fun db ->
                   let open Deferred.Result.Let_syntax in
                   let%bind height = Q.Max_block_height.run db () in
                   let%bind latest_ts = Q.Latest_block_timestamp.run db () in
                   let%bind missing =
                     Q.Missing_blocks_count.run db ~missing_blocks_width:window
                       ()
                   in
                   let%bind unparented = Q.Unparented_blocks_count.run db () in
                   return (height, latest_ts, missing, unparented) )
             with
             | Error e ->
                 if timed_out () then
                   if json then (
                     output
                       Output.(
                         to_json
                           { empty with
                             ready = Some false
                           ; timed_out = Some true
                           ; error = Some (Error.to_string_hum e)
                           }) ;
                     exit 1 )
                   else
                     Deferred.Or_error.errorf "timed out: %s"
                       (Error.to_string_hum e)
                 else (
                   eprintf "[%3ds] DB unreachable: %s\n" (elapsed ())
                     (Error.to_string_hum e) ;
                   let%bind () = after (Time.Span.of_int_sec interval) in
                   loop () )
             | Ok (height, latest_ts, missing, unparented) ->
                 let ready, delay_secs, _problems =
                   evaluate_readiness ~latest_ts ~missing ~unparented ~max_delay
                     ~max_missing ~max_unparented
                 in
                 if ready then (
                   if json then
                     output
                       Output.(
                         to_json
                           { empty with
                             ready = Some true
                           ; block_height = Some height
                           ; delay_seconds = Some delay_secs
                           ; missing_blocks = Some missing
                           ; unparented_blocks = Some unparented
                           })
                   else print_endline "READY" ;
                   Deferred.Or_error.return () )
                 else if timed_out () then
                   if json then (
                     output
                       Output.(
                         to_json
                           { empty with
                             ready = Some false
                           ; timed_out = Some true
                           ; block_height = Some height
                           ; delay_seconds = Some delay_secs
                           ; missing_blocks = Some missing
                           ; unparented_blocks = Some unparented
                           }) ;
                     exit 1 )
                   else
                     Deferred.Or_error.errorf "timed out waiting for readiness"
                 else (
                   eprintf
                     "[%3ds] height=%d delay=%Lds missing=%d unparented=%d\n"
                     (elapsed ()) height delay_secs missing unparented ;
                   let%bind () = after (Time.Span.of_int_sec interval) in
                   loop () )
           in
           if db_only then db_only_loop () else loop () )

let () =
  Command.run
    (Command.group
       ~summary:
         "Mina archive healthcheck CLI — lightweight probe commands for \
          archive node monitoring"
       [ ("db-ready", db_ready_command)
       ; ("block-height", block_height_command)
       ; ("block-recency", block_recency_command)
       ; ("missing-blocks", missing_blocks_command)
       ; ("unparented-blocks", unparented_blocks_command)
       ; ("ready", ready_command)
       ; ("wait", wait_command)
       ] )
