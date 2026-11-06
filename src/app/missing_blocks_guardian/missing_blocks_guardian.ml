(* missing_blocks_guardian.ml -- populate an archive database with missing
   blocks, fetched one by one from a bucket of precomputed or extensional
   blocks. The commands are here; the flags and the settings are in Cli and
   Config. *)

open Core
open Async
open Missing_blocks_guardian_lib

let top_blocks_count = 10

let connect ~logger archive_uri =
  match Mina_caqti.connect_pool archive_uri with
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

(* Logs the reason of a failure and exits with 1. *)
let or_exit ~logger = function
  | Ok value ->
      return value
  | Error reason ->
      [%log fatal] "%s" reason ;
      exit 1

let check ~logger ~pool = Auditor.check ~logger ~pool >>= or_exit ~logger

(* The bucket must answer at start, so that a wrong URL is reported as such
   and not later as a block that cannot be downloaded. *)
let check_bucket ~logger (blocks : Config.blocks) =
  match%bind Download.probe ~url:blocks.url ~network:blocks.network with
  | Ok () ->
      return ()
  | Error err ->
      [%log fatal]
        "Cannot start: the bucket %s failed the check: %s. Check \
         --precomputed-blocks-url or PRECOMPUTED_BLOCKS_URL, and --network or \
         MINA_NETWORK."
        blocks.url (Error.to_string_hum err) ;
      exit 1

let bootstrap ~logger ~pool (blocks : Config.blocks)
    (parent : Auditor.missing_parent) =
  [%log info] "Some blocks are missing, moving to recovery" ;
  let%bind () = log_top_blocks ~logger ~pool ~when_:"before the recovery" in
  [%log info] "Restoring blocks one by one from $url"
    ~metadata:[ ("url", `String blocks.url) ] ;
  let add_block =
    Archive_blocks.add_block ~logger ~pool ~format:blocks.format
  in
  let%bind () =
    Recovery.restore ~logger ~add_block
      ~check:(fun () -> Auditor.check ~logger ~pool)
      blocks parent
    >>= or_exit ~logger
  in
  log_top_blocks ~logger ~pool ~when_:"after the recovery"

(* Exits 0 when no block is missing and 1 when some are. *)
let audit ~logger archive_uri =
  let pool = connect ~logger archive_uri in
  match%bind check ~logger ~pool with
  | Some _ ->
      [%log info] "Some blocks are missing" ;
      exit 1
  | None ->
      [%log info] "The archive has no missing blocks back to genesis" ;
      return ()

let recover ~logger ~pool blocks =
  match%bind check ~logger ~pool with
  | Some parent ->
      let%map () = bootstrap ~logger ~pool blocks parent in
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
  Deferred.ignore_m (recover ~logger ~pool blocks)

(* Checks every [interval] seconds forever; after a recovery, waits
   [recovery_sleep_factor] times longer. *)
let daemon ~logger ~interval archive blocks =
  let pool = connect ~logger archive in
  let%bind () = check_bucket ~logger blocks in
  let rec loop () =
    let%bind recovered = recover ~logger ~pool blocks in
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
