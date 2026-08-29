(* missing_blocks_guardian.ml -- audit an archive database and fill the gaps
   in it.

   This single executable replaces the pair it was built from:

     - [mina-missing-blocks-auditor], an OCaml executable that reported gaps,
       and
     - [mina-missing-blocks-guardian], a bash script that ran the auditor,
       piped its log through jq, downloaded the reported parent block with
       curl and gave it to [mina-archive-blocks].

   The subcommands and the environment variables are the ones the bash script
   used, so existing deployments do not change.  What used to be
   [mina-missing-blocks-auditor --archive-uri URI] is now
   [mina-missing-blocks-guardian audit --archive-uri URI]. *)

open Core
open Async
open Missing_blocks_guardian_lib

let die ~logger error =
  [%log fatal] "$error"
    ~metadata:[ ("error", `String (Error.to_string_hum error)) ] ;
  exit 1

let or_die ~logger deferred =
  match%bind deferred with Ok x -> return x | Error err -> die ~logger err

let warn_about_obsolete_env_vars ~logger =
  List.iter (Config.obsolete_env_vars_in_use ()) ~f:(fun (name, why) ->
      [%log warn]
        "$variable is set but has no effect any more: $reason. Remove it from \
         the environment."
        ~metadata:[ ("variable", `String name); ("reason", `String why) ] )

(** Connect, and prove the connection can read the archive schema, before
    anything is downloaded.  A wrong database or an un-migrated schema is a
    different problem from a missing block and has to read as one. *)
let connect (config : Config.t) ~logger =
  let uri = Config.redacted_archive_uri config.archive_uri in
  [%log info] "Connecting to the archive database at $archive_uri"
    ~metadata:[ ("archive_uri", `String uri) ] ;
  match Mina_caqti.connect_pool ~max_size:128 config.archive_uri with
  | Error err ->
      die ~logger
        (Error.createf "could not connect to the archive database %s: %s" uri
           (Caqti_error.show err) )
  | Ok pool ->
      let%bind block_count =
        or_die ~logger
          (Deferred.map (Audit.preflight pool) ~f:(fun result ->
               Or_error.tag result
                 ~tag:
                   (sprintf
                      "the archive database %s cannot be read. Check the \
                       connection settings, and that the archive schema has \
                       been created and migrated"
                      uri ) ) )
      in
      [%log info]
        "Connected to the archive database, which holds $blocks blocks"
        ~metadata:[ ("blocks", `String (Int64.to_string block_count)) ] ;
      return pool

let setup ~requires_blocks flags =
  let logger = Logger.create () in
  warn_about_obsolete_env_vars ~logger ;
  match Config.resolve ~requires_blocks flags with
  | Error err ->
      die ~logger err
  | Ok config ->
      let%map pool = connect config ~logger in
      (config, pool, logger)

let handle_termination ~logger =
  Signal.handle [ Signal.term; Signal.int ] ~f:(fun signal ->
      [%log info] "Received $signal, exiting"
        ~metadata:[ ("signal", `String (Signal.to_string signal)) ] ;
      Core.exit 1 )

let audit_command =
  Command.async
    ~summary:
      "Report the blocks missing from an archive database and the gaps in its \
       chain statuses"
    ~readme:(fun () ->
      "Nothing is written to the database.\n\n\
       The exit code is a bit mask, so several problems can be reported at once:\n\
      \  bit 0 (1)  some blocks have no parent in the archive\n\
      \  bit 1 (2)  some blocks below the highest canonical block are still \
       pending\n\
      \  bit 2 (4)  the canonical chain is shorter than the highest canonical \
       height\n\
      \  bit 3 (8)  a block on the canonical chain has another chain status\n\
      \  bit 4 (16) the archive holds no genesis block and no first \
       post-hard-fork block\n\n\
       Bits 0 to 3 have the meaning they had in mina-missing-blocks-auditor, \
       which this subcommand replaces." )
    (Command.Param.map Config.param ~f:(fun flags () ->
         let%bind config, pool, logger = setup ~requires_blocks:false flags in
         let%bind report =
           or_die ~logger (Audit.report pool ~min_height:config.min_height)
         in
         Audit.log_report ~logger report ;
         if Audit.Report.is_healthy report then
           [%log info]
             "This archive node is synced with no missing blocks back to \
              genesis"
         else [%log info] "The archive is not healthy; see the report above" ;
         Core.exit (Audit.Report.exit_code report) ) )

(* What a repair pass achieved.  [`Incomplete] is a pass that ran to the end
   without an internal failure but still left a gap open -- a block that is
   not in the bucket, an ingest the archive rejected, or the --max-blocks
   limit.  It has to be told apart from [`Repaired] so that the exit code and
   the daemon's sleep are honest about it. *)
let repair_once (config : Config.t) ~pool ~logger ~genesis_constants
    ~constraint_constants ~proof_cache_db =
  let open Deferred.Or_error.Let_syntax in
  let%bind report = Audit.report pool ~min_height:config.min_height in
  Audit.log_report ~logger report ;
  if List.is_empty report.Audit.Report.orphans then (
    [%log info]
      "This archive node is synced with no missing blocks back to genesis" ;
    return `Already_healthy )
  else
    let%map outcome =
      Guardian.repair config ~pool ~logger ~genesis_constants
        ~constraint_constants ~proof_cache_db
    in
    let unresolved = outcome.Guardian.unresolved in
    [%log info]
      "Repair pass finished: $blocks_added blocks added, $branches_unresolved \
       branches still open"
      ~metadata:
        [ ("blocks_added", `Int outcome.Guardian.blocks_added)
        ; ("branches_unresolved", `Int (List.length unresolved))
        ] ;
    if Guardian.is_complete outcome then `Repaired
    else (
      List.iter unresolved ~f:(fun u ->
          [%log error] "Block $state_hash still has no parent: $reason"
            ~metadata:(Guardian.Unresolved.to_metadata u) ) ;
      `Incomplete )

let single_run_command ~genesis_constants ~constraint_constants =
  Command.async
    ~summary:"Check the archive database once and fill any gap found, then exit"
    ~readme:(fun () ->
      "Blocks are downloaded from --precomputed-blocks-url and written \
       directly to the archive database. Exits 0 when the archive holds no \
       block without a parent, and 1 when a gap could not be closed -- \
       including when the pass stopped at --max-blocks with gaps left, and for \
       every --dry-run that found a block it could not fetch." )
    (Command.Param.map Config.param ~f:(fun flags () ->
         let%bind config, pool, logger = setup ~requires_blocks:true flags in
         handle_termination ~logger ;
         let proof_cache_db = Proof_cache_tag.create_identity_db () in
         let%bind result =
           or_die ~logger
             (repair_once config ~pool ~logger ~genesis_constants
                ~constraint_constants ~proof_cache_db )
         in
         match result with
         | `Already_healthy | `Repaired ->
             Core.exit 0
         | `Incomplete ->
             Core.exit 1 ) )

let daemon_command ~genesis_constants ~constraint_constants =
  Command.async
    ~summary:
      "Check the archive database on a timer and fill any gap found, forever"
    ~readme:(fun () ->
      "Waits --interval seconds between checks, and --idle-multiplier times \
       that after a pass that added blocks. Exits non-zero after \
       --max-consecutive-failures passes fail in a row, so that a supervisor \
       can restart it." )
    (Command.Param.map Config.param ~f:(fun flags () ->
         let%bind config, pool, logger = setup ~requires_blocks:true flags in
         handle_termination ~logger ;
         let proof_cache_db = Proof_cache_tag.create_identity_db () in
         let sleep span =
           [%log info] "Checking again in $minutes minutes"
             ~metadata:[ ("minutes", `Float (Time_ns.Span.to_min span)) ] ;
           Clock_ns.after span
         in
         let rec loop ~consecutive_failures =
           match%bind
             repair_once config ~pool ~logger ~genesis_constants
               ~constraint_constants ~proof_cache_db
           with
           | Ok `Already_healthy ->
               let%bind () = sleep config.interval in
               loop ~consecutive_failures:0
           | Ok `Repaired ->
               (* Only a pass that closed every gap earns the long sleep, the
                  way the bash guardian slept 6*TIMEOUT after a completed
                  bootstrap.  A pass that stopped early must come back at the
                  normal interval, or a rate-limited backfill runs
                  --idle-multiplier times slower than configured. *)
               let%bind () =
                 sleep
                   (Time_ns.Span.scale config.interval
                      (Int.to_float config.idle_multiplier) )
               in
               loop ~consecutive_failures:0
           | Ok `Incomplete ->
               let%bind () = sleep config.interval in
               loop ~consecutive_failures:0
           | Error err ->
               let consecutive_failures = consecutive_failures + 1 in
               [%log error] "Repair pass failed ($failures in a row): $error"
                 ~metadata:
                   [ ("failures", `Int consecutive_failures)
                   ; ("error", `String (Error.to_string_hum err))
                   ] ;
               if
                 Int.( > ) config.max_consecutive_failures 0
                 && Int.( >= ) consecutive_failures
                      config.max_consecutive_failures
               then
                 die ~logger
                   (Error.tag err
                      ~tag:
                        (sprintf
                           "giving up after %d failed repair passes in a row"
                           consecutive_failures ) )
               else
                 let%bind () = sleep config.interval in
                 loop ~consecutive_failures
         in
         loop ~consecutive_failures:0 ) )

let () =
  let (module G) = Genesis_constants.profiled () in
  let genesis_constants = G.genesis_constants in
  let constraint_constants = G.constraint_constants in
  Command_unix.run
    (Command.group
       ~summary:
         "Audit a Mina archive database and fill the gaps in it from a block \
          source"
       ~readme:(fun () ->
         "Settings come from the command line flags, or from the environment \
          variables the bash guardian used, which the flags override:\n\n\
         \  PG_CONN, or DB_USERNAME, PGPASSWORD, DB_HOST, DB_PORT, DB_NAME\n\
         \                          the archive database (--archive-uri)\n\
         \  PRECOMPUTED_BLOCKS_URL  where the block files are \
          (--precomputed-blocks-url)\n\
         \  MINA_NETWORK            block file name prefix (--network)\n\
         \  BLOCKS_FORMAT           precomputed or extensional (--block-format)\n\
         \  TIMEOUT                 seconds between checks in daemon mode \
          (--interval)\n\n\
          MISSING_BLOCKS_AUDITOR and ARCHIVE_BLOCKS are no longer used: this \
          app audits and ingests by itself." )
       [ ("audit", audit_command)
       ; ( "single-run"
         , single_run_command ~genesis_constants ~constraint_constants )
       ; ("daemon", daemon_command ~genesis_constants ~constraint_constants)
       ] )
