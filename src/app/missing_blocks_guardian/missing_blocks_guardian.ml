(* missing_blocks_guardian.ml -- populate an archive database with missing
   blocks, fetched one by one from a bucket of precomputed or extensional
   blocks *)

open Core
open Async

module Block_format = struct
  type t = Precomputed | Extensional

  let to_string = function
    | Precomputed ->
        "precomputed"
    | Extensional ->
        "extensional"

  let of_string = function
    | "precomputed" ->
        Precomputed
    | "extensional" ->
        Extensional
    | other ->
        failwithf "unknown block format %s, expected precomputed or extensional"
          other ()

  let arg_type = Command.Arg_type.create of_string
end

(* The archive database and the program that audits it. *)
type archive = { uri : Uri.t; auditor : string }

(* Where the missing blocks come from and the program that writes them. *)
type blocks =
  { url : string
  ; network : string
  ; format : Block_format.t
  ; archive_blocks : string
  }

module Default = struct
  let auditor = "mina-missing-blocks-auditor"

  let archive_blocks = "mina-archive-blocks"

  let interval = 600
end

(* After a recovery, the daemon waits this many intervals. *)
let recovery_sleep_factor = 6

let top_blocks_count = 10

let connect ~logger archive =
  match Mina_caqti.connect_pool archive.uri with
  | Ok pool ->
      pool
  | Error err ->
      [%log fatal] "Could not connect to the archive database: $error"
        ~metadata:[ ("error", `String (Caqti_error.show err)) ] ;
      Core.exit 1

let log_top_blocks ~logger ~pool ~when_ =
  match%map
    Mina_caqti.Pool.use (fun db -> Sql.Top_blocks.run db top_blocks_count) pool
  with
  | Ok blocks ->
      [%log info] "Top %d blocks %s: $blocks" top_blocks_count when_
        ~metadata:
          [ ( "blocks"
            , `List
                (List.map blocks ~f:(fun (state_hash, height) ->
                     `Assoc
                       [ ("state_hash", `String state_hash)
                       ; ("height", `Int height)
                       ] ) ) )
          ]
  | Error err ->
      [%log error] "Could not query the top blocks: $error"
        ~metadata:[ ("error", `String (Caqti_error.show err)) ]

let check ~logger archive =
  Auditor.check ~logger ~prog:archive.auditor ~archive_uri:archive.uri

let download ~logger blocks file =
  let url = blocks.url ^ "/" ^ file in
  [%log info] "Downloading block $file from $url"
    ~metadata:[ ("file", `String file); ("url", `String url) ] ;
  match%bind Download.fetch ~url ~file with
  | Ok () ->
      return ()
  | Error err ->
      [%log fatal]
        "Could not download $file: $error. Check --precomputed-blocks-url."
        ~metadata:
          [ ("file", `String file)
          ; ("error", `String (Error.to_string_hum err))
          ] ;
      exit 1

let remove ~logger file =
  match%bind Monitor.try_with_or_error (fun () -> Unix.unlink file) with
  | Ok () ->
      return ()
  | Error err ->
      [%log fatal] "Could not remove $file: $error"
        ~metadata:
          [ ("file", `String file)
          ; ("error", `String (Error.to_string_hum err))
          ] ;
      exit 1

(* Writes [file] to the archive with mina-archive-blocks and removes it. The
   log of mina-archive-blocks is relayed; its exit code is 0 even when the
   block was not added. *)
let populate ~logger archive blocks file =
  let uri = Uri.to_string archive.uri in
  let prog = blocks.archive_blocks in
  match%bind
    Subprocess.run ~logger ~secrets:[ uri ] ~prog
      ~args:
        [ "--" ^ Block_format.to_string blocks.format
        ; "--archive-uri"
        ; uri
        ; file
        ]
      ()
  with
  | Error err ->
      [%log fatal] "Could not run $prog: $error"
        ~metadata:
          [ ("prog", `String prog)
          ; ("error", `String (Error.to_string_hum err))
          ] ;
      exit 1
  | Ok output -> (
      ( match App_log.parse output.stdout with
      | Ok messages ->
          App_log.relay ~logger messages
      | Error err ->
          [%log warn] "Could not read the log of $prog: $error"
            ~metadata:
              [ ("prog", `String prog)
              ; ("error", `String (Error.to_string_hum err))
              ] ) ;
      match output.exit_status with
      | Error _ ->
          let%bind () = remove ~logger file in
          [%log fatal] "$prog failed. The database remains unhealthy."
            ~metadata:[ ("prog", `String prog) ] ;
          exit 1
      | Ok () ->
          [%log info] "Populated the database with $file"
            ~metadata:[ ("file", `String file) ] ;
          remove ~logger file )

(* Imports [parent] from the bucket, then each next missing parent that the
   auditor reports, until it reports none. *)
let bootstrap ~logger ~pool archive blocks (parent : Auditor.missing_parent) =
  [%log info] "Some blocks are missing, moving to recovery" ;
  let%bind () = log_top_blocks ~logger ~pool ~when_:"before the recovery" in
  [%log info] "Restoring blocks one by one from $url"
    ~metadata:[ ("url", `String blocks.url) ] ;
  let rec loop = function
    | None ->
        return ()
    | Some { Auditor.hash; height } ->
        let file = sprintf "%s-%d-%s.json" blocks.network height hash in
        let%bind () = download ~logger blocks file in
        let%bind () = populate ~logger archive blocks file in
        let%bind parent = check ~logger archive in
        loop parent
  in
  let%bind () = loop (Some parent) in
  log_top_blocks ~logger ~pool ~when_:"after the recovery"

let audit ~logger archive =
  let%map parent = check ~logger archive in
  match parent with
  | Some _ ->
      [%log info] "Some blocks are missing"
  | None ->
      [%log info] "The archive has no missing blocks back to genesis"

let recover ~logger ~pool archive blocks =
  match%bind check ~logger archive with
  | Some parent ->
      let%map () = bootstrap ~logger ~pool archive blocks parent in
      [%log info]
        "The recovery finished, the archive has no missing blocks back to \
         genesis" ;
      true
  | None ->
      [%log info] "The archive has no missing blocks back to genesis" ;
      return false

let single_run ~logger archive blocks =
  let pool = connect ~logger archive in
  Deferred.ignore_m (recover ~logger ~pool archive blocks)

(* Checks every [interval] seconds forever; after a recovery, waits
   [recovery_sleep_factor] times longer. *)
let daemon ~logger ~interval archive blocks =
  let pool = connect ~logger archive in
  let rec loop () =
    let%bind recovered = recover ~logger ~pool archive blocks in
    let sleep =
      if recovered then recovery_sleep_factor * interval else interval
    in
    [%log info] "Checking again in %d seconds" sleep ;
    let%bind () = after (Time.Span.of_int_sec sleep) in
    loop ()
  in
  loop ()

(* The environment variables of the bash script this program replaces. Each
   flag falls back to its variable, so the program is configured the same way
   as before. *)
module Env = struct
  let get name =
    match Sys.getenv name with
    | Some value when not (String.is_empty value) ->
        Some value
    | _ ->
        None

  (* The value of the flag, else of the environment variable, else the
     default. Fails when there is none. *)
  let or_default ?default ~flag ~env ~of_string value =
    match (value, get env, default) with
    | Some value, _, _ ->
        value
    | None, Some text, _ -> (
        try of_string text
        with exn ->
          let reason =
            match exn with Failure msg -> msg | exn -> Exn.to_string exn
          in
          failwithf "invalid value of the environment variable %s: %s" env
            reason () )
    | None, None, Some default ->
        default
    | None, None, None ->
        failwithf "missing %s: pass the flag or set the environment variable %s"
          flag env ()

  let archive_uri_vars =
    [ "DB_USERNAME"; "PGPASSWORD"; "DB_HOST"; "DB_PORT"; "DB_NAME" ]

  (* The archive URI, from --archive-uri or from the five variables the bash
     script built its connection string from. *)
  let archive_uri = function
    | Some uri ->
        Uri.of_string uri
    | None -> (
        let values = List.map archive_uri_vars ~f:get in
        match values with
        | [ Some user; Some password; Some host; Some port; Some database ] ->
            let port =
              try Int.of_string port
              with _ ->
                failwithf
                  "invalid value of the environment variable DB_PORT: %s" port
                  ()
            in
            Uri.make ~scheme:"postgres"
              ~userinfo:(user ^ ":" ^ password)
              ~host ~port ~path:("/" ^ database) ()
        | _ ->
            let missing =
              List.filter_map (List.zip_exn archive_uri_vars values)
                ~f:(fun (name, value) ->
                  Option.some_if (Option.is_none value) name )
            in
            let not_set =
              if List.length missing = List.length archive_uri_vars then ""
              else sprintf " (not set: %s)" (String.concat ~sep:", " missing)
            in
            failwithf
              "missing --archive-uri: pass the flag or set the environment \
               variables %s%s"
              (String.concat ~sep:", " archive_uri_vars)
              not_set () )
end

module Flags = struct
  open Command.Let_syntax

  let log_level =
    Command.Arg_type.map Command.Param.string ~f:(fun name ->
        match Logger.Level.of_string (String.lowercase name) with
        | Ok level ->
            level
        | Error _ ->
            failwithf "unknown log level %s, expected one of: %s" name
              (String.concat ~sep:", "
                 (List.map Logger.Level.all ~f:Logger.Level.show) )
              () )

  (* Sets up the log on stdout, as --log-json and --log-level do in the other
     Mina programs. *)
  let log =
    let%map_open json =
      flag "--log-json" ~aliases:[ "log-json" ] no_arg
        ~doc:"Print log output as JSON (default: plain text)"
    and level =
      flag "--log-level" ~aliases:[ "log-level" ]
        ~doc:"LEVEL Set log level (default: Info)"
        (optional_with_default Logger.Level.Info log_level)
    in
    fun () ->
      let processor =
        if json then Logger.Processor.raw ~log_level:level ()
        else
          Logger.Processor.pretty ~log_level:level
            ~config:
              { Interpolator_lib.Interpolator.mode = Inline
              ; max_interpolation_length = 50
              ; pretty_print = true
              }
      in
      Logger.Consumer_registry.register ~id:"default" ~processor
        ~transport:(Logger.Transport.stdout ())
        ()

  let archive =
    let%map_open uri =
      flag "--archive-uri" ~aliases:[ "archive-uri" ]
        ~doc:
          "URI Archive database to check and repair, for example \
           postgres://user:password@localhost:5432/archive (or DB_USERNAME, \
           PGPASSWORD, DB_HOST, DB_PORT and DB_NAME)"
        (optional string)
    and auditor =
      flag "--missing-blocks-auditor"
        ~aliases:[ "missing-blocks-auditor" ]
        ~doc:
          (sprintf
             "PATH mina-missing-blocks-auditor program (or \
              MISSING_BLOCKS_AUDITOR; default: %s)"
             Default.auditor )
        (optional string)
    in
    { uri = Env.archive_uri uri
    ; auditor =
        Env.or_default auditor ~flag:"--missing-blocks-auditor"
          ~env:"MISSING_BLOCKS_AUDITOR" ~default:Default.auditor
          ~of_string:Fn.id
    }

  let blocks =
    let%map_open url =
      flag "--precomputed-blocks-url"
        ~aliases:[ "precomputed-blocks-url" ]
        ~doc:
          "URL Bucket with the block files, as an http, https or file URL (or \
           PRECOMPUTED_BLOCKS_URL)"
        (optional string)
    and network =
      flag "--network" ~aliases:[ "network" ]
        ~doc:
          "NAME Network name, the prefix of the block file names (or \
           MINA_NETWORK)"
        (optional string)
    and format =
      flag "--block-format" ~aliases:[ "block-format" ]
        ~doc:
          "precomputed|extensional Format of the block files (or \
           BLOCKS_FORMAT; default: precomputed)"
        (optional Block_format.arg_type)
    and archive_blocks =
      flag "--archive-blocks" ~aliases:[ "archive-blocks" ]
        ~doc:
          (sprintf
             "PATH mina-archive-blocks program (or ARCHIVE_BLOCKS; default: %s)"
             Default.archive_blocks )
        (optional string)
    in
    { url =
        Env.or_default url ~flag:"--precomputed-blocks-url"
          ~env:"PRECOMPUTED_BLOCKS_URL" ~of_string:Fn.id
    ; network =
        Env.or_default network ~flag:"--network" ~env:"MINA_NETWORK"
          ~of_string:Fn.id
    ; format =
        Env.or_default format ~flag:"--block-format" ~env:"BLOCKS_FORMAT"
          ~default:Block_format.Precomputed ~of_string:Block_format.of_string
    ; archive_blocks =
        Env.or_default archive_blocks ~flag:"--archive-blocks"
          ~env:"ARCHIVE_BLOCKS" ~default:Default.archive_blocks ~of_string:Fn.id
    }

  let interval =
    let%map_open interval =
      flag "--interval" ~aliases:[ "interval" ]
        ~doc:
          (sprintf
             "SECONDS Time between two checks; after a recovery, %d times \
              longer (or TIMEOUT; default: %d)"
             recovery_sleep_factor Default.interval )
        (optional int)
    in
    Env.or_default interval ~flag:"--interval" ~env:"TIMEOUT"
      ~default:Default.interval ~of_string:Int.of_string
end

let audit_command =
  Command.async ~summary:"Check whether the archive has missing blocks"
    (let%map_open.Command setup_log = Flags.log and archive = Flags.archive in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       audit ~logger archive )

let single_run_command =
  Command.async ~summary:"Check the archive and restore its missing blocks"
    (let%map_open.Command setup_log = Flags.log
     and archive = Flags.archive
     and blocks = Flags.blocks in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       single_run ~logger archive blocks )

let daemon_command =
  Command.async
    ~summary:"Check the archive and restore its missing blocks, repeatedly"
    (let%map_open.Command setup_log = Flags.log
     and archive = Flags.archive
     and blocks = Flags.blocks
     and interval = Flags.interval in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       daemon ~logger ~interval archive blocks )

let () =
  Command.run
    (Command.group
       ~summary:"Find and restore the blocks missing from an archive database"
       [ ("audit", audit_command)
       ; ("single-run", single_run_command)
       ; ("daemon", daemon_command)
       ] )
