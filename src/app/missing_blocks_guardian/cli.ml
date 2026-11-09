(* cli.ml -- the command line: the flags of each setting, the log setup,
   the check of the settings and the report of the settings in use *)

open Core
open Command.Let_syntax

(* Each flag is optional here. Config fills it from its environment
   variable or its default and reports every problem at once. Each flag
   function takes the environment and returns the checked setting. *)

(* The log on stdout, with --log-json and --log-level as in the other Mina
   programs. *)
let log =
  let%map_open json = Cli_lib.Flag.Log.json
  and level = Cli_lib.Flag.Log.level in
  fun () -> Cli_lib.Stdout_log.setup json level

let archive =
  let%map_open uri =
    flag "--archive-uri" ~aliases:[ "archive-uri" ]
      ~doc:
        "URI Archive database to check and repair, for example \
         postgres://user:password@localhost:5432/archive (or DB_USERNAME, \
         PGPASSWORD, DB_HOST, DB_PORT and DB_NAME)"
      (optional string)
  in
  fun ~env -> Config.archive_uri ~env uri

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
  in
  fun ~env -> Config.blocks ~env ~url ~network ~format

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
          [%log fatal] "Cannot start: %s" problem ) ;
      Core.exit 1

let log_archive ~logger archive_uri =
  [%log info] "Archive database $archive"
    ~metadata:[ ("archive", `String (Config.redact archive_uri)) ]

let log_blocks ~logger (blocks : Config.blocks) =
  [%log info]
    "Block files $network-<height>-<state hash>.json from $url, in the $format \
     format"
    ~metadata:
      [ ("network", `String blocks.network)
      ; ("url", `String blocks.url)
      ; ("format", `String (Config.Block_format.to_string blocks.format))
      ]
