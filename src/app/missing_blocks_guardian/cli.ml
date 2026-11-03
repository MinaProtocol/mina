(* cli.ml -- the command line: the flags of each setting, the log setup,
   the check of the settings and the report of the settings in use *)

open Core
open Command.Let_syntax

(* Each flag is optional here. Config fills it from its environment
   variable or its default and reports every problem at once. Each flag
   function takes the environment and returns the checked setting. *)

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
      ~doc:(sprintf "LEVEL Set log level, one of %s (default: Info)" log_levels)
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
           "SECONDS Time between two checks; after a recovery, %d times longer \
            (or TIMEOUT; default: %d)"
           Config.Default.recovery_sleep_factor Config.Default.interval )
      (optional string)
  in
  fun ~env -> Config.interval ~env interval

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
