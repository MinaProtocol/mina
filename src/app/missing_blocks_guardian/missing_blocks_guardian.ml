(* missing_blocks_guardian.ml -- populate an archive database with missing
   blocks, fetched one by one from a bucket of precomputed or extensional
   blocks *)

open Core
open Async
open Missing_blocks_guardian_lib

(* After a recovery, the daemon waits this many intervals. *)
let recovery_sleep_factor = 6

let top_blocks_count = 10

(* The settings, or every problem with them in the log and exit 1. *)
let or_exit ~logger = function
  | Ok value ->
      value
  | Error problems ->
      List.iter problems ~f:(fun problem ->
          [%log fatal] "Cannot start: $problem"
            ~metadata:[ ("problem", `String problem) ] ) ;
      Core.exit 1

let log_archive ~logger (archive : Config.archive) =
  [%log info] "Archive database $archive, audited with $auditor"
    ~metadata:
      [ ("archive", `String (Config.redact archive.uri))
      ; ("auditor", `String archive.auditor)
      ]

let log_blocks ~logger (blocks : Config.blocks) =
  [%log info]
    "Block files $network-<height>-<state hash>.json from $url, in the $format \
     format, written with $archive_blocks"
    ~metadata:
      [ ("network", `String blocks.network)
      ; ("url", `String blocks.url)
      ; ("format", `String (Config.Block_format.to_string blocks.format))
      ; ("archive_blocks", `String blocks.archive_blocks)
      ]

let connect ~logger (archive : Config.archive) =
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

let check ~logger (archive : Config.archive) =
  Auditor.check ~logger ~prog:archive.auditor ~archive_uri:archive.uri

let download ~logger (blocks : Config.blocks) file =
  let url = blocks.url ^ "/" ^ file in
  [%log info] "Downloading block $file from $url"
    ~metadata:[ ("file", `String file); ("url", `String url) ] ;
  match%bind Download.fetch ~url ~file with
  | Ok () ->
      return ()
  | Error err ->
      [%log fatal]
        "Could not download $file: $error. Check --precomputed-blocks-url and \
         --network."
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
   log of mina-archive-blocks is relayed. Its exit code is 0 even when the
   block was not added, so an error in its log is the failure. *)
let populate ~logger (archive : Config.archive) (blocks : Config.blocks) file =
  let uri = Uri.to_string archive.uri in
  let prog = blocks.archive_blocks in
  let failed error =
    let%bind () = remove ~logger file in
    [%log fatal]
      "$prog could not add $file: $error. The database remains unhealthy."
      ~metadata:
        [ ("prog", `String prog)
        ; ("file", `String file)
        ; ("error", `String error)
        ] ;
    exit 1
  in
  match%bind
    Subprocess.run ~logger ~secrets:[ uri ] ~prog
      ~args:
        [ "--" ^ Config.Block_format.to_string blocks.format
        ; "--archive-uri"
        ; uri
        ; file
        ]
      ()
  with
  | Error err ->
      failed (sprintf "it could not be run: %s" (Error.to_string_hum err))
  | Ok output -> (
      let messages, other_lines = App_log.parse output.stdout in
      App_log.relay ~logger messages ;
      App_log.warn_other_lines ~logger ~prog other_lines ;
      match (App_log.first_error messages, output.exit_status) with
      | Some message, _ ->
          failed (App_log.describe message)
      | None, Error (`Exit_non_zero code) ->
          failed (sprintf "it exited with %d" code)
      | None, Error (`Signal signal) ->
          failed
            (sprintf "it was killed by signal %s" (Signal.to_string signal))
      | None, Ok () ->
          [%log info] "Populated the database with $file"
            ~metadata:[ ("file", `String file) ] ;
          remove ~logger file )

(* Imports [parent] from the bucket, then each next missing parent that the
   auditor reports, until it reports none. Stops when an import changes
   nothing, so that one bad block file cannot keep it busy forever. *)
let bootstrap ~logger ~pool (archive : Config.archive) (blocks : Config.blocks)
    (parent : Auditor.missing_parent) =
  [%log info] "Some blocks are missing, moving to recovery" ;
  let%bind () = log_top_blocks ~logger ~pool ~when_:"before the recovery" in
  [%log info] "Restoring blocks one by one from $url"
    ~metadata:[ ("url", `String blocks.url) ] ;
  let rec loop (parent : Auditor.missing_parent) =
    let file =
      sprintf "%s-%d-%s.json" blocks.network parent.height parent.hash
    in
    let%bind () = download ~logger blocks file in
    let%bind () = populate ~logger archive blocks file in
    match%bind check ~logger archive with
    | None ->
        return ()
    | Some next when Auditor.equal_missing_parent next parent ->
        [%log fatal]
          "Added $file, but the archive still lacks block $hash at height \
           $height. The database remains unhealthy."
          ~metadata:
            [ ("file", `String file)
            ; ("hash", `String parent.hash)
            ; ("height", `Int parent.height)
            ] ;
        exit 1
    | Some next ->
        loop next
  in
  let%bind () = loop parent in
  log_top_blocks ~logger ~pool ~when_:"after the recovery"

(* Exits 0 when no block is missing and 1 when some are. *)
let audit ~logger archive =
  match%bind check ~logger archive with
  | Some _ ->
      [%log info] "Some blocks are missing" ;
      exit 1
  | None ->
      [%log info] "The archive has no missing blocks back to genesis" ;
      return ()

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

(* Each flag is optional here. Config fills it from its environment
   variable or its default and reports every problem at once. *)
module Flags = struct
  open Command.Let_syntax

  let log_levels =
    String.concat ~sep:", " (List.map Logger.Level.all ~f:Logger.Level.show)

  (* Sets up the log on stdout, as --log-json and --log-level do in the other
     Mina programs. *)
  let log =
    let%map_open json =
      flag "--log-json" ~aliases:[ "log-json" ] no_arg
        ~doc:"Print log output as JSON (default: plain text)"
    and level =
      flag "--log-level" ~aliases:[ "log-level" ]
        ~doc:
          (sprintf "LEVEL Set log level, one of %s (default: Info)" log_levels)
        (optional_with_default "info" string)
    in
    fun () ->
      let level =
        match Logger.Level.of_string (String.lowercase level) with
        | Ok level ->
            level
        | Error _ ->
            Stdlib.prerr_endline
              (sprintf "Cannot start: --log-level %s: expected one of %s" level
                 log_levels ) ;
            Core.exit 1
      in
      let processor =
        if json then Logger.Processor.raw ~log_level:level ()
        else
          Logger.Processor.pretty ~log_level:level
            ~config:
              { Interpolator_lib.Interpolator.mode = Inline
              ; max_interpolation_length = 200
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
             Config.Default.auditor )
        (optional string)
    in
    fun ~env -> Config.archive ~env ~uri ~auditor

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
          (sprintf
             "precomputed|extensional Format of the block files (or \
              BLOCKS_FORMAT; default: %s)"
             (Config.Block_format.to_string Config.Default.format) )
        (optional string)
    and archive_blocks =
      flag "--archive-blocks" ~aliases:[ "archive-blocks" ]
        ~doc:
          (sprintf
             "PATH mina-archive-blocks program (or ARCHIVE_BLOCKS; default: %s)"
             Config.Default.archive_blocks )
        (optional string)
    in
    fun ~env -> Config.blocks ~env ~url ~network ~format ~archive_blocks

  let interval =
    let%map_open interval =
      flag "--interval" ~aliases:[ "interval" ]
        ~doc:
          (sprintf
             "SECONDS Time between two checks; after a recovery, %d times \
              longer (or TIMEOUT; default: %d)"
             recovery_sleep_factor Config.Default.interval )
        (optional string)
    in
    fun ~env -> Config.interval ~env interval
end

let audit_command =
  Command.async ~summary:"Check whether the archive has missing blocks"
    (let%map_open.Command setup_log = Flags.log and archive = Flags.archive in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       let archive = or_exit ~logger (archive ~env:Config.process_env) in
       log_archive ~logger archive ;
       audit ~logger archive )

let single_run_command =
  Command.async ~summary:"Check the archive and restore its missing blocks"
    (let%map_open.Command setup_log = Flags.log
     and archive = Flags.archive
     and blocks = Flags.blocks in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       let env = Config.process_env in
       let archive, blocks =
         or_exit ~logger (Config.both (archive ~env) (blocks ~env))
       in
       log_archive ~logger archive ;
       log_blocks ~logger blocks ;
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
       let env = Config.process_env in
       let (archive, blocks), interval =
         or_exit ~logger
           (Config.both
              (Config.both (archive ~env) (blocks ~env))
              (interval ~env) )
       in
       log_archive ~logger archive ;
       log_blocks ~logger blocks ;
       [%log info] "Checking every %d seconds" interval ;
       daemon ~logger ~interval archive blocks )

let () =
  Command.run
    (Command.group
       ~summary:"Find and restore the blocks missing from an archive database"
       [ ("audit", audit_command)
       ; ("single-run", single_run_command)
       ; ("daemon", daemon_command)
       ] )
