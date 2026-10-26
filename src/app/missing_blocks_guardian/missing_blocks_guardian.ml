(* missing_blocks_guardian.ml -- populate an archive database with missing
   blocks, fetched one by one from a bucket of precomputed or extensional
   blocks. *)

open Core
open Async

module Default = struct
  let missing_blocks_auditor = "mina-missing-blocks-auditor"

  let archive_blocks = "mina-archive-blocks"

  let blocks_format = "precomputed"

  let timeout = 600
end

(* After a recovery, the daemon waits this many times [TIMEOUT]. *)
let recovery_sleep_factor = 6

let synced_message =
  "[RESOLUTION] This Archive node is synced with no missing blocks back to \
   genesis!"

let usage name =
  print_string
    (sprintf
       {|Usage: %s <subcommand> [options]
Subcommands:
  audit           Check database health
  single-run      Check database health and recover it if broken
  daemon          Run as a daemon checking health every 10 minutes

Options:
  --help          Show this help message

Environment variables:
  Required:
    DB_USERNAME             Database username
    DB_HOST                 Database connection endpoint
    DB_PORT                 Database connection port
    DB_NAME                 Database name
    PGPASSWORD              Postgresql password
    PRECOMPUTED_BLOCKS_URL  Url of the bucket with the precomputed blocks
    MINA_NETWORK            Mina network (used for precomputed blocks prefix)

  Optional:
    MISSING_BLOCKS_AUDITOR  Path to the missing-blocks-auditor exe (default: %s)
    ARCHIVE_BLOCKS          Path to the archive blocks exe (default: %s)
    BLOCKS_FORMAT           Block format type. Possible values: [precomputed/extensional] (default: %s)
    TIMEOUT                 Time to sleep in seconds when in daemon mode. After recovery it will sleep six times more (default: %d)

Example:
  %s audit
  %s single-run
  %s daemon
|}
       name Default.missing_blocks_auditor Default.archive_blocks
       Default.blocks_format Default.timeout name name name )

let fail message = print_endline message ; exit 1

let log_error err = eprintf "%s\n" (Error.to_string_hum err)

type config =
  { pg_conn : string
  ; precomputed_blocks_url : string
  ; mina_network : string
  ; missing_blocks_auditor : string
  ; archive_blocks : string
  ; blocks_format : string
  ; timeout : int
  }

let getenv_non_empty name =
  match Sys.getenv name with Some "" | None -> None | value -> value

let config_of_env () =
  let required name =
    match getenv_non_empty name with
    | Some value ->
        return value
    | None ->
        fail
          (sprintf
             "[ERROR] The %s environment variable is not set or is empty. \
              Exiting the script"
             name )
  in
  let optional ?shown_default name ~default =
    match getenv_non_empty name with
    | Some value ->
        value
    | None ->
        print_endline
          (sprintf
             "[INFO] The %s environment variable is not set or is empty. \
              Defaulting to \027[31m%s\027[m."
             name
             (Option.value shown_default ~default) ) ;
        default
  in
  let%bind db_username = required "DB_USERNAME" in
  let%bind pgpassword = required "PGPASSWORD" in
  let%bind db_host = required "DB_HOST" in
  let%bind db_port = required "DB_PORT" in
  let%bind db_name = required "DB_NAME" in
  let%bind precomputed_blocks_url = required "PRECOMPUTED_BLOCKS_URL" in
  let%bind mina_network = required "MINA_NETWORK" in
  let missing_blocks_auditor =
    optional "MISSING_BLOCKS_AUDITOR"
      ~shown_default:"mina-missing-block-auditor"
      ~default:Default.missing_blocks_auditor
  in
  let blocks_format = optional "BLOCKS_FORMAT" ~default:Default.blocks_format in
  let archive_blocks =
    optional "ARCHIVE_BLOCKS" ~default:Default.archive_blocks
  in
  let timeout = optional "TIMEOUT" ~default:(Int.to_string Default.timeout) in
  let%map timeout =
    match Option.try_with (fun () -> Int.of_string timeout) with
    | Some timeout ->
        return timeout
    | None ->
        fail (sprintf "[ERROR] TIMEOUT is not a number: %s" timeout)
  in
  print_endline
    (sprintf
       "[INFO] Using connection string postgres://%s:<your_password>@%s:%s/%s"
       db_username db_host db_port db_name ) ;
  { pg_conn =
      sprintf "postgres://%s:%s@%s:%s/%s" db_username pgpassword db_host db_port
        db_name
  ; precomputed_blocks_url
  ; mina_network
  ; missing_blocks_auditor
  ; archive_blocks
  ; blocks_format
  ; timeout
  }

(* Runs [prog], passes its stderr through and returns its stdout. If [prog]
   cannot be started, writes [<prog>: <error>] to stderr and returns no output
   and exit code 127. *)
let run_capture ~prog ~args =
  match%bind Process.create ~prog ~args () with
  | Error err ->
      eprintf "%s: %s\n" prog (Error.to_string_hum err) ;
      return ("", Error (`Exit_non_zero 127))
  | Ok process ->
      let stderr = Lazy.force Writer.stderr in
      let%bind () =
        Pipe.iter_without_pushback
          (Reader.pipe (Process.stderr process))
          ~f:(Writer.write stderr)
      and stdout = Reader.contents (Process.stdout process)
      and status = Process.wait process in
      return (stdout, status)

(* One JSON value on each line; blank lines are ignored. *)
let parse_log_lines output =
  Or_error.try_with (fun () ->
      String.split_lines output
      |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))
      |> List.map ~f:Yojson.Safe.from_string )

(* A string as is, any other value as JSON. *)
let json_to_text = function
  | `String s ->
      s
  | json ->
      Yojson.Safe.to_string json

let field name = function
  | `Assoc fields ->
      List.Assoc.find fields ~equal:String.equal name
      |> Option.value ~default:`Null
  | _ ->
      `Null

let messages lines =
  List.map lines ~f:(fun line -> json_to_text (field "message" line))
  |> String.concat ~sep:"\n"

(* The parent of the first logged block whose parent is missing:
   [(parent_hash, parent_height)]. *)
let first_missing_parent lines =
  List.find_map lines ~f:(fun line ->
      let metadata = field "metadata" line in
      match (field "parent_hash" metadata, field "parent_height" metadata) with
      | `Null, _ | _, `Null ->
          None
      | parent_hash, parent_height ->
          Some (json_to_text parent_hash, json_to_text parent_height) )

(* The exit code of the auditor is ignored; only its log is read. *)
let run_auditor config =
  let%bind output, _status =
    run_capture ~prog:config.missing_blocks_auditor
      ~args:[ "--archive-uri"; config.pg_conn ]
  in
  match parse_log_lines output with
  | Ok lines ->
      return lines
  | Error err ->
      log_error err ;
      fail
        "[ERROR] mina-missing-blocks-auditor failed. The database remains \
         unhealthy.\n\
         For more information about the error try running \
         mina-missing-blocks-auditor separately."

(* Runs the auditor, prints its messages after [prefix] and returns the first
   missing parent. *)
let check config ~prefix =
  let%map lines = run_auditor config in
  print_endline (prefix ^ messages lines) ;
  first_missing_parent lines

let top_blocks_sql =
  "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"

let top_blocks_query =
  Mina_caqti.collect_req Caqti_type.unit
    Caqti_type.(t2 string int)
    top_blocks_sql

let query_top_blocks config =
  let open Deferred.Result.Let_syntax in
  let%bind (module Conn : Mina_caqti.CONNECTION) =
    Mina_caqti.connect (Uri.of_string config.pg_conn)
  in
  let%bind rows = Conn.collect_list top_blocks_query () in
  let%map () = Conn.disconnect () |> Deferred.ok in
  rows

let align_left text ~width = text ^ String.make (width - String.length text) ' '

let align_right text ~width =
  String.make (width - String.length text) ' ' ^ text

let center text ~width =
  let padding = width - String.length text in
  let left = padding / 2 in
  String.make left ' ' ^ text ^ String.make (padding - left) ' '

(* Prints the query, then an aligned table with a row count. *)
let print_top_blocks config =
  match%map query_top_blocks config with
  | Error err ->
      Error (Error.of_string (Caqti_error.show err))
  | Ok rows ->
      let rows =
        List.map rows ~f:(fun (state_hash, height) ->
            (state_hash, Int.to_string height) )
      in
      let width header column =
        List.fold rows ~init:(String.length header) ~f:(fun width row ->
            Int.max width (String.length (column row)) )
      in
      let hash_width = width "state_hash" fst in
      let height_width = width "height" snd in
      print_endline top_blocks_sql ;
      print_endline
        (sprintf " %s | %s "
           (center "state_hash" ~width:hash_width)
           (center "height" ~width:height_width) ) ;
      print_endline
        (sprintf "%s+%s"
           (String.make (hash_width + 2) '-')
           (String.make (height_width + 2) '-') ) ;
      List.iter rows ~f:(fun (state_hash, height) ->
          print_endline
            (sprintf " %s | %s"
               (align_left state_hash ~width:hash_width)
               (align_right height ~width:height_width) ) ) ;
      print_endline
        ( match List.length rows with
        | 1 ->
            "(1 row)\n"
        | count ->
            sprintf "(%d rows)\n" count ) ;
      Ok ()

(* RFC 6125 name matching: a leading "*" stands for one whole label. *)
let host_matches ~host name =
  let host = String.lowercase host and name = String.lowercase name in
  match String.chop_prefix name ~prefix:"*." with
  | None ->
      String.equal host name
  | Some suffix -> (
      match String.lsplit2 host ~on:'.' with
      | Some (label, rest) ->
          (not (String.is_empty label)) && String.equal rest suffix
      | None ->
          false )

(* The default TLS client checks only the certificate chain. This also checks
   that the certificate SAN (subject alternative name) list contains [host]. *)
let ssl_config url =
  Option.map (Uri.host url) ~f:(fun host ->
      Conduit_async.V2.Ssl.Config.create ~hostname:host
        ~verify:(fun connection ->
          return
            ( match Async_ssl.Ssl.Connection.peer_certificate connection with
            | Some (Ok certificate) ->
                List.exists
                  (Async_ssl.Ssl.Certificate.subject_alt_names certificate)
                  ~f:(host_matches ~host)
            | Some (Error _) | None ->
                false ) )
        () )

let download_block config file =
  print_endline (sprintf "[BOOTSTRAP] Downloading %s block" file) ;
  let url = Uri.of_string (config.precomputed_blocks_url ^ "/" ^ file) in
  (* The body is saved for all HTTP statuses. *)
  let%bind result =
    Monitor.try_with_or_error (fun () ->
        match Uri.scheme url with
        | Some ("http" | "https") ->
            let%bind _response, body =
              Cohttp_async.Client.get ?ssl_config:(ssl_config url) url
            in
            let%bind body = Cohttp_async.Body.to_string body in
            Writer.save file ~contents:body
        | Some "file" ->
            let%bind contents = Reader.file_contents (Uri.path url) in
            Writer.save file ~contents
        | _ ->
            failwith "Protocol not supported" )
  in
  match result with
  | Ok () ->
      return ()
  | Error err ->
      log_error err ;
      fail
        "[ERROR] Curl failed to download block. The database remains unhealthy.\n\
        \ Make sure your PRECOMPUTED_BLOCKS_URL environment variable is set \
         correctly."

let remove_file file = Monitor.try_with_or_error (fun () -> Unix.unlink file)

(* Prints the message of the last line of the mina-archive-blocks log. *)
let print_populated output =
  match parse_log_lines output with
  | Ok lines ->
      let last = Option.value (List.last lines) ~default:`Null in
      print_endline
        (sprintf "[BOOTSTRAP] Populated database with block: %s"
           (json_to_text (field "message" last)) )
  | Error err ->
      log_error err

let populate_db config file =
  print_endline
    (sprintf "%s --%s --archive-uri %s %s" config.archive_blocks
       config.blocks_format config.pg_conn file ) ;
  let%bind output, status =
    run_capture ~prog:config.archive_blocks
      ~args:
        [ "--" ^ config.blocks_format; "--archive-uri"; config.pg_conn; file ]
  in
  match status with
  | Error _ ->
      let%bind (_ : unit Or_error.t) = remove_file file in
      fail
        "[ERROR] mina-archive-blocks failed. The database remains unhealthy.\n\
        \ Make sure the environment variables are set correctly and the \
         database is accessible."
  | Ok () -> (
      print_populated output ;
      match%bind remove_file file with
      | Ok () ->
          return ()
      | Error _ ->
          fail
            "[ERROR] Failed to remove block file. The database remains \
             unhealthy.\n\
            \ Make sure the environment variables PRECOMPUTED_BLOCKS_URL and \
             MINA_NETWORK are set correctly." )

(* Imports [parent] from the bucket, then each next missing parent that the
   auditor reports, until it reports none. *)
let bootstrap config ~parent =
  print_endline
    "[BOOTSTRAP] Some blocks are missing, moving to recovery logic..." ;
  print_endline "[BOOTSTRAP] Top 10 blocks before bootstrapping the archiveDB:" ;
  let%bind () =
    match%bind print_top_blocks config with
    | Ok () ->
        return ()
    | Error err ->
        log_error err ;
        fail
          "[ERROR] Psql failed to connect. The database remains unhealthy.\n\
          \ Make sure you can connect to the database with psql nad that the \
           connection string is correct."
  in
  print_endline
    (sprintf "[BOOTSTRAP] Restoring blocks individually from %s..."
       config.precomputed_blocks_url ) ;
  let rec loop = function
    | None ->
        return ()
    | Some (parent_hash, parent_height) ->
        let file =
          sprintf "%s-%s-%s.json" config.mina_network parent_height parent_hash
        in
        let%bind () = download_block config file in
        let%bind () = populate_db config file in
        let%bind lines = run_auditor config in
        loop (first_missing_parent lines)
  in
  let%bind () = loop (Some parent) in
  print_endline "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:" ;
  let%map () =
    match%map print_top_blocks config with
    | Ok () ->
        ()
    | Error err ->
        log_error err
  in
  print_endline synced_message

let audit config =
  print_endline "[INFO] Running in audit mode" ;
  let%bind parent = check config ~prefix:"[INFO] " in
  print_endline
    ( if Option.is_some parent then "[RESOLUTION] Some blocks are missing"
    else synced_message ) ;
  exit 0

let single_run config =
  print_endline "[INFO] Running in single-run mode" ;
  let%bind () =
    match%bind check config ~prefix:"[BOOTSTRAP] " with
    | Some parent ->
        bootstrap config ~parent
    | None ->
        return ()
  in
  print_endline
    "[RESOLUTION] The bootstrap process finished successfully, the Archive \
     node is synced with no missing blocks to genesis!" ;
  exit 0

(* Checks every [TIMEOUT] seconds forever; after a recovery, waits
   [recovery_sleep_factor] times longer. *)
let daemon config =
  print_endline "[INFO] Running in daemon mode" ;
  let rec loop () =
    let%bind () =
      match%bind check config ~prefix:"[BOOTSTRAP] " with
      | Some parent ->
          let%bind () = bootstrap config ~parent in
          let sleep = recovery_sleep_factor * config.timeout in
          print_endline
            (sprintf "[INFO] Checking again in %d minutes..." (sleep / 60)) ;
          after (Time.Span.of_int_sec sleep)
      | None ->
          print_endline
            (sprintf
               "[RESOLUTION] Database has no missing blocks to genesis for the \
                moment! Waiting for %d minutes."
               (config.timeout / 60) ) ;
          after (Time.Span.of_int_sec config.timeout)
    in
    loop ()
  in
  loop ()

let main ~name args =
  Signal.handle [ Signal.hup; Signal.int; Signal.quit ] ~f:(fun _ ->
      print_endline "\nRecieved termination signal. Exiting the script\n" ;
      don't_wait_for (exit 1) ) ;
  match args with
  | [] ->
      usage name ; exit 1
  | "--help" :: _ ->
      usage name ; exit 0
  | subcommand :: _ -> (
      let%bind config = config_of_env () in
      match subcommand with
      | "audit" ->
          audit config
      | "single-run" ->
          single_run config
      | "daemon" ->
          daemon config
      | _ ->
          usage name ; exit 1 )

let () =
  let argv = Sys.get_argv () in
  don't_wait_for (main ~name:argv.(0) (List.tl_exn (Array.to_list argv))) ;
  never_returns (Scheduler.go ())
