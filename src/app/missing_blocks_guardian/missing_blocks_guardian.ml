(* missing_blocks_guardian.ml -- populate an archive database with missing
   blocks, fetched one by one from a bucket of precomputed or extensional
   blocks. The commands are here; the flags and the settings are in Cli and
   Config. *)

open Core
open Async
open Missing_blocks_guardian_lib

let top_blocks_count = 10

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

(* The bucket must answer at start, so that a wrong URL is reported as such
   and not later as a block that cannot be downloaded. *)
let check_bucket ~logger (blocks : Config.blocks) =
  match%bind Download.probe ~url:blocks.url with
  | Ok () ->
      return ()
  | Error err ->
      [%log fatal]
        "Cannot start: the bucket %s does not answer: %s. Check \
         --precomputed-blocks-url or PRECOMPUTED_BLOCKS_URL."
        blocks.url (Error.to_string_hum err) ;
      exit 1

let block_file (blocks : Config.blocks) (parent : Auditor.missing_parent) =
  sprintf "%s-%d-%s.json" blocks.network parent.height parent.hash

(* Downloads the file of [parent] from the bucket and returns its name. The
   bucket answered at start, so a failure here is about the file: the error
   shows how its URL was built. *)
let download ~logger (blocks : Config.blocks) (parent : Auditor.missing_parent)
    =
  let file = block_file blocks parent in
  let url = blocks.url ^ "/" ^ file in
  [%log info] "Downloading block $file from $url"
    ~metadata:[ ("file", `String file); ("url", `String url) ] ;
  match%bind Download.fetch ~url ~file with
  | Ok () ->
      return file
  | Error err ->
      [%log fatal]
        "Could not download the block at height %d with state hash %s: %s. Its \
         URL %s is <bucket URL>/<network>-<height>-<state hash>.json, with the \
         bucket URL %s from --precomputed-blocks-url or PRECOMPUTED_BLOCKS_URL \
         and the network %s from --network or MINA_NETWORK. The bucket \
         answered at start, so check the network name and whether the block is \
         in the bucket."
        parent.height parent.hash (Error.to_string_hum err) url blocks.url
        blocks.network ;
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
          failed (sprintf "it exited with %d%s" code (Subprocess.wrote output))
      | None, Error (`Signal signal) ->
          failed
            (sprintf "it was killed by signal %s%s" (Signal.to_string signal)
               (Subprocess.wrote output) )
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
    let%bind file = download ~logger blocks parent in
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
  let%bind () = check_bucket ~logger blocks in
  Deferred.ignore_m (recover ~logger ~pool archive blocks)

(* Checks every [interval] seconds forever; after a recovery, waits
   [recovery_sleep_factor] times longer. *)
let daemon ~logger ~interval archive blocks =
  let pool = connect ~logger archive in
  let%bind () = check_bucket ~logger blocks in
  let rec loop () =
    let%bind recovered = recover ~logger ~pool archive blocks in
    let sleep =
      if recovered then Config.Default.recovery_sleep_factor * interval
      else interval
    in
    [%log info] "Checking again in %d seconds" sleep ;
    let%bind () = after (Time.Span.of_int_sec sleep) in
    loop ()
  in
  loop ()

let audit_command =
  Command.async ~summary:"Check whether the archive has missing blocks"
    (let%map_open.Command setup_log = Cli.log and archive = Cli.archive in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       let archive = Cli.or_exit ~logger (archive ~env:Config.process_env) in
       Cli.log_archive ~logger archive ;
       audit ~logger archive )

let single_run_command =
  Command.async ~summary:"Check the archive and restore its missing blocks"
    (let%map_open.Command setup_log = Cli.log
     and archive = Cli.archive
     and blocks = Cli.blocks in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       let env = Config.process_env in
       let archive, blocks =
         Cli.or_exit ~logger (Config.both (archive ~env) (blocks ~env))
       in
       Cli.log_archive ~logger archive ;
       Cli.log_blocks ~logger blocks ;
       single_run ~logger archive blocks )

let daemon_command =
  Command.async
    ~summary:"Check the archive and restore its missing blocks, repeatedly"
    (let%map_open.Command setup_log = Cli.log
     and archive = Cli.archive
     and blocks = Cli.blocks
     and interval = Cli.interval in
     fun () ->
       setup_log () ;
       let logger = Logger.create () in
       let env = Config.process_env in
       let (archive, blocks), interval =
         Cli.or_exit ~logger
           (Config.both
              (Config.both (archive ~env) (blocks ~env))
              (interval ~env) )
       in
       Cli.log_archive ~logger archive ;
       Cli.log_blocks ~logger blocks ;
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
