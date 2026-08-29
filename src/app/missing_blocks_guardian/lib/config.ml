(* config.ml -- resolve the guardian's settings from command line flags and
   environment variables.

   Every setting the bash guardian took from the environment is still taken
   from the same variable, so existing deployments keep working unchanged.  A
   command line flag is available for each of them and wins when both are
   given.

   Missing settings are collected and reported together, naming both the flag
   and the environment variable.  The bash guardian exited on the first unset
   variable, so an operator with three unset variables had to run it three
   times to learn that. *)

open Core

(** Values taken straight off the command line, before any environment
    variable is consulted. *)
type flags =
  { archive_uri : string option
  ; precomputed_blocks_url : string option
  ; network : string option
  ; block_format : string option
  ; interval : float option
  ; idle_multiplier : int option
  ; http_timeout : float option
  ; retries : int option
  ; retry_delay : float option
  ; max_blocks : int option
  ; min_height : int option
  ; max_consecutive_failures : int option
  ; dry_run : bool
  }

type t =
  { archive_uri : Uri.t
  ; blocks : Block_source.t option
        (** [None] for [audit], which reads no blocks *)
  ; network : string option
  ; format : Ingest.format
  ; interval : Time_ns.Span.t
  ; idle_multiplier : int
  ; http_timeout : Time_ns.Span.t
  ; retries : int
  ; retry_delay : Time_ns.Span.t
  ; max_blocks : int option
  ; min_height : int option
  ; max_consecutive_failures : int
  ; dry_run : bool
  }

let default_interval_seconds = 600.

let default_idle_multiplier = 6

let default_http_timeout_seconds = 60.

let default_retries = 3

let default_retry_delay_seconds = 5.

let default_max_consecutive_failures = 5

(** Environment variables the bash guardian used that this app no longer
    needs, because it does the auditing and the ingesting itself. *)
let obsolete_env_vars =
  [ ( "MISSING_BLOCKS_AUDITOR"
    , "the audit runs inside this app; there is no separate auditor executable \
       to point at" )
  ; ( "ARCHIVE_BLOCKS"
    , "blocks are written through the archive library inside this app; \
       mina-archive-blocks is no longer run as a subprocess" )
  ]

(* An empty variable counts as unset, which is how the bash guardian's [-z]
   tests behaved. *)
let env name =
  match Sys.getenv name with
  | Some value when not (String.is_empty (String.strip value)) ->
      Some (String.strip value)
  | _ ->
      None

let obsolete_env_vars_in_use () =
  List.filter obsolete_env_vars ~f:(fun (name, _) -> Option.is_some (env name))

let flag_or_env flag env_name = Option.first_some flag (env env_name)

(** Build the archive URI. Preferred sources, in order: [--archive-uri], then
    [PG_CONN], then the five [DB_*] and [PGPASSWORD] variables the bash
    guardian assembled the connection string from. *)
let resolve_archive_uri (flags : flags) =
  match flag_or_env flags.archive_uri "PG_CONN" with
  | Some uri ->
      Ok (Uri.of_string uri)
  | None -> (
      let user = env "DB_USERNAME" in
      let password = env "PGPASSWORD" in
      let host = env "DB_HOST" in
      let port = env "DB_PORT" in
      let db = env "DB_NAME" in
      let missing =
        List.filter_map
          [ ("DB_USERNAME", user)
          ; ("PGPASSWORD", password)
          ; ("DB_HOST", host)
          ; ("DB_PORT", port)
          ; ("DB_NAME", db)
          ]
          ~f:(fun (name, value) ->
            if Option.is_none value then Some name else None )
      in
      match (user, password, host, port, db) with
      | Some user, Some password, Some host, Some port, Some db -> (
          match Int.of_string_opt port with
          | None ->
              Or_error.errorf "DB_PORT must be a port number, but it is %S" port
          | Some port ->
              Ok
                (Uri.make ~scheme:"postgres"
                   ~userinfo:(user ^ ":" ^ password)
                   ~host ~port ~path:("/" ^ db) () ) )
      | _ ->
          Or_error.errorf
            "no archive database to connect to. Pass --archive-uri, or set \
             PG_CONN, or set all of DB_USERNAME, PGPASSWORD, DB_HOST, DB_PORT \
             and DB_NAME (unset: %s)"
            (String.concat ~sep:", " missing) )

(* Query parameters a libpq connection URI may carry a secret in.  The
   PostgreSQL driver accepts them, so they can appear in PG_CONN. *)
let secret_query_params = [ "password"; "sslpassword" ]

(** The connection string with every secret replaced, safe to log.  A libpq
    URI can hold the password in the userinfo or in the query string, so both
    are covered. *)
let redacted_archive_uri uri =
  let uri =
    match Uri.password uri with
    | None ->
        uri
    | Some _ ->
        Uri.with_password uri (Some "REDACTED")
  in
  let query =
    List.map (Uri.query uri) ~f:(fun (key, values) ->
        if
          List.mem secret_query_params (String.lowercase key)
            ~equal:String.equal
        then (key, List.map values ~f:(fun _ -> "REDACTED"))
        else (key, values) )
  in
  Uri.to_string (Uri.with_query uri query)

let positive_span name value =
  if Float.( > ) value 0. then Ok (Time_ns.Span.of_sec value)
  else Or_error.errorf "%s must be greater than zero, but it is %f" name value

let non_negative name value =
  if Int.( >= ) value 0 then Ok value
  else Or_error.errorf "%s must not be negative, but it is %d" name value

let resolve ~requires_blocks (flags : flags) =
  let open Or_error.Let_syntax in
  let%bind archive_uri = resolve_archive_uri flags in
  let%bind format =
    match flag_or_env flags.block_format "BLOCKS_FORMAT" with
    | None ->
        Ok Ingest.Precomputed
    | Some s ->
        Ingest.format_of_string (String.lowercase s)
  in
  let network = flag_or_env flags.network "MINA_NETWORK" in
  let blocks_url =
    flag_or_env flags.precomputed_blocks_url "PRECOMPUTED_BLOCKS_URL"
  in
  let%bind blocks =
    if not requires_blocks then Ok None
    else
      let missing =
        List.filter_opt
          [ ( if Option.is_none blocks_url then
                Some "--precomputed-blocks-url (or PRECOMPUTED_BLOCKS_URL)"
              else None )
          ; ( if Option.is_none network then Some "--network (or MINA_NETWORK)"
              else None )
          ]
      in
      match blocks_url with
      | Some url when List.is_empty missing ->
          let%map source = Block_source.create url in
          Some source
      | _ ->
          Or_error.errorf
            "cannot fetch blocks without %s. A block file name is built as \
             <network>-<height>-<state hash>.json under the block source URL, \
             so both the URL and the network name are needed."
            (String.concat ~sep:" and " missing)
  in
  let%bind interval_seconds =
    match flags.interval with
    | Some seconds ->
        Ok seconds
    | None -> (
        match env "TIMEOUT" with
        | None ->
            Ok default_interval_seconds
        | Some raw -> (
            (* Reject a TIMEOUT that is not a number rather than silently
               falling back to the default poll interval. *)
            match Float.of_string_opt raw with
            | Some seconds ->
                Ok seconds
            | None ->
                Or_error.errorf
                  "TIMEOUT must be a number of seconds, but it is %S. Use \
                   --interval to set it on the command line."
                  raw ) )
  in
  let%bind interval = positive_span "--interval (TIMEOUT)" interval_seconds in
  let%bind http_timeout =
    positive_span "--http-timeout"
      (Option.value flags.http_timeout ~default:default_http_timeout_seconds)
  in
  let%bind retry_delay =
    positive_span "--retry-delay"
      (Option.value flags.retry_delay ~default:default_retry_delay_seconds)
  in
  let%bind retries =
    non_negative "--retries"
      (Option.value flags.retries ~default:default_retries)
  in
  let%bind idle_multiplier =
    let value =
      Option.value flags.idle_multiplier ~default:default_idle_multiplier
    in
    if Int.( >= ) value 1 then Ok value
    else
      Or_error.errorf "--idle-multiplier must be at least 1, but it is %d" value
  in
  let%bind max_consecutive_failures =
    non_negative "--max-consecutive-failures"
      (Option.value flags.max_consecutive_failures
         ~default:default_max_consecutive_failures )
  in
  let%bind max_blocks =
    match flags.max_blocks with
    | None ->
        Ok None
    | Some n when Int.( > ) n 0 ->
        Ok (Some n)
    | Some n ->
        Or_error.errorf "--max-blocks must be greater than zero, but it is %d" n
  in
  let%map min_height =
    match flags.min_height with
    | None ->
        Ok None
    | Some n when Int.( >= ) n 1 ->
        Ok (Some n)
    | Some n ->
        Or_error.errorf "--min-height must be at least 1, but it is %d" n
  in
  { archive_uri
  ; blocks
  ; network
  ; format
  ; interval
  ; idle_multiplier
  ; http_timeout
  ; retries
  ; retry_delay
  ; max_blocks
  ; min_height
  ; max_consecutive_failures
  ; dry_run = flags.dry_run
  }

let param =
  let%map_open.Command archive_uri =
    flag "--archive-uri" (optional string)
      ~doc:
        "URI Archive database to check and repair, for example \
         postgres://user:password@localhost:5432/archive. Overrides PG_CONN \
         and the DB_* variables."
  and precomputed_blocks_url =
    flag "--precomputed-blocks-url" (optional string)
      ~doc:
        "URL Location of the block files, as an http, https or file URL, or a \
         local directory. Overrides PRECOMPUTED_BLOCKS_URL."
  and network =
    flag "--network" (optional string)
      ~doc:
        "NAME Network name used as the block file name prefix. Overrides \
         MINA_NETWORK."
  and block_format =
    flag "--block-format" (optional string)
      ~doc:
        "precomputed|extensional Format of the block files. Overrides \
         BLOCKS_FORMAT. Default: precomputed."
  and interval =
    flag "--interval" (optional float)
      ~doc:
        "SECONDS Time to wait between checks in daemon mode. Overrides \
         TIMEOUT. Default: 600."
  and idle_multiplier =
    flag "--idle-multiplier" (optional int)
      ~doc:
        "N In daemon mode, wait N times --interval after a repair adds blocks. \
         Default: 6."
  and http_timeout =
    flag "--http-timeout" (optional float)
      ~doc:"SECONDS Time allowed for one block download. Default: 60."
  and retries =
    flag "--retries" (optional int)
      ~doc:
        "N Extra attempts for a download that fails for a transient reason. A \
         missing or malformed block is never retried. Default: 3."
  and retry_delay =
    flag "--retry-delay" (optional float)
      ~doc:"SECONDS Time to wait between download attempts. Default: 5."
  and max_blocks =
    flag "--max-blocks" (optional int)
      ~doc:"N Stop after adding N blocks in one repair pass. Default: no limit."
  and min_height =
    flag "--min-height" (optional int)
      ~doc:
        "HEIGHT Refuse to fetch a block below this height. Use it on a forked \
         network whose archive does not hold the fork block, to stop the walk \
         at the fork point instead of running down to height 1."
  and max_consecutive_failures =
    flag "--max-consecutive-failures" (optional int)
      ~doc:
        "N Exit in daemon mode after N repair passes fail in a row. 0 means \
         never exit. Default: 5."
  and dry_run =
    flag "--dry-run" no_arg
      ~doc:
        " Report what would be downloaded and check that it can be downloaded \
         and decoded, without writing anything to the database."
  in
  { archive_uri
  ; precomputed_blocks_url
  ; network
  ; block_format
  ; interval
  ; idle_multiplier
  ; http_timeout
  ; retries
  ; retry_delay
  ; max_blocks
  ; min_height
  ; max_consecutive_failures
  ; dry_run
  }

let%test_module "config" =
  ( module struct
    let no_flags =
      { archive_uri = None
      ; precomputed_blocks_url = None
      ; network = None
      ; block_format = None
      ; interval = None
      ; idle_multiplier = None
      ; http_timeout = None
      ; retries = None
      ; retry_delay = None
      ; max_blocks = None
      ; min_height = None
      ; max_consecutive_failures = None
      ; dry_run = false
      }

    let%test "a flag archive URI is used as given" =
      match
        resolve ~requires_blocks:false
          { no_flags with archive_uri = Some "postgres://u:p@h:5432/archive" }
      with
      | Ok t ->
          String.equal
            (Uri.to_string t.archive_uri)
            "postgres://u:p@h:5432/archive"
      | Error _ ->
          false

    let%test "the password is not in the redacted URI" =
      let redacted =
        redacted_archive_uri (Uri.of_string "postgres://u:hunter2@h:5432/db")
      in
      (not (String.is_substring redacted ~substring:"hunter2"))
      && String.is_substring redacted ~substring:"REDACTED"

    let%test "a URI without a password is left alone" =
      String.equal
        (redacted_archive_uri (Uri.of_string "postgres://u@h:5432/db"))
        "postgres://u@h:5432/db"

    let%test "an unset archive database is reported, not guessed" =
      match resolve ~requires_blocks:false no_flags with
      | Error err ->
          String.is_substring (Error.to_string_hum err) ~substring:"PG_CONN"
      | Ok _ ->
          false

    let%test "fetching blocks needs both a URL and a network" =
      match
        resolve ~requires_blocks:true
          { no_flags with
            archive_uri = Some "postgres://u:p@h:5432/archive"
          ; precomputed_blocks_url = Some "https://example.com/blocks"
          }
      with
      | Error err ->
          String.is_substring (Error.to_string_hum err) ~substring:"--network"
      | Ok _ ->
          false

    let%test "a bad --min-height is rejected" =
      Or_error.is_error
        (resolve ~requires_blocks:false
           { no_flags with
             archive_uri = Some "postgres://u:p@h:5432/archive"
           ; min_height = Some 0
           } )

    let%test "a bad --interval is rejected" =
      Or_error.is_error
        (resolve ~requires_blocks:false
           { no_flags with
             archive_uri = Some "postgres://u:p@h:5432/archive"
           ; interval = Some 0.
           } )

    let%test "a query-string password is redacted too" =
      let redacted =
        redacted_archive_uri
          (Uri.of_string
             "postgres://u@h:5432/db?password=hunter2&sslmode=require" )
      in
      (not (String.is_substring redacted ~substring:"hunter2"))
      && String.is_substring redacted ~substring:"REDACTED"
      && String.is_substring redacted ~substring:"sslmode=require"

    let%test "an unknown block format is rejected" =
      Or_error.is_error
        (resolve ~requires_blocks:false
           { no_flags with
             archive_uri = Some "postgres://u:p@h:5432/archive"
           ; block_format = Some "extensionall"
           } )
  end )
