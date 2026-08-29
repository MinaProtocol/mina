(* guardian.ml -- walk back from every block whose parent is missing and fill
   the gap from the block source.

   The bash guardian repeated

     PARENT_FILE=$($MISSING_BLOCKS_AUDITOR ... | jq ... )
     curl -sO "$URL/$PARENT_FILE"
     $ARCHIVE_BLOCKS ... "$PARENT_FILE"

   until the auditor reported no parent.  That loop had three ways to spin
   forever without saying why: a 404 downloaded as an error page, an ingest
   that failed while reporting success, and a chain that does not reach a
   genesis or fork block in the archive, so the walk runs down past height 1.
   Each of those is a named, terminating error here. *)

open Core
open Async

type outcome = { blocks_added : int; branches_left_alone : int }

let describe_state pool ~logger ~when_ =
  match%map
    Mina_caqti.Pool.use
      (fun db -> Archive_health_queries.Max_block_height.run db ())
      pool
  with
  | Ok height ->
      [%log info] "Archive state $when: the highest block height is $height"
        ~metadata:[ ("when", `String when_); ("height", `Int height) ]
  | Error err ->
      [%log warn] "Could not read the highest block height $when"
        ~metadata:
          [ ("when", `String when_); ("error", `String (Caqti_error.show err)) ]

(** Name of the block file that closes the gap under [orphan]. *)
let parent_file_name ~network (orphan : Audit.Orphan.t) =
  Block_source.block_file_name ~network
    ~height:(Audit.Orphan.parent_height orphan)
    ~state_hash:orphan.parent_hash

(** The lowest height the walk is allowed to ask for.  Below height 1 there is
    nothing to fetch; [--min-height] raises the floor for a forked archive
    whose fork block is not marked as one. *)
let height_floor (config : Config.t) = Option.value config.min_height ~default:1

let fetch_parent (config : Config.t) ~source ~network ~logger orphan =
  let name = parent_file_name ~network orphan in
  [%log info] "Downloading $block_file"
    ~metadata:
      [ ("block_file", `String name)
      ; ("url", `String (Block_source.location source ~name))
      ] ;
  Block_source.fetch source ~name ~timeout:config.http_timeout
    ~retries:config.retries ~retry_delay:config.retry_delay ~logger

let log_below_floor ~logger ~floor ~(config : Config.t) (orphan : Audit.Orphan.t)
    =
  let metadata = Audit.Orphan.to_metadata orphan @ [ ("floor", `Int floor) ] in
  match config.min_height with
  | Some _ ->
      [%log info]
        "Stopping the walk under $state_hash at the height floor $floor, as \
         asked by --min-height"
        ~metadata
  | None ->
      [%log error]
        "Block $state_hash at height $height has no parent, but there is no \
         block below it to fetch. The archive does not reach a genesis or \
         hard-fork block. Restore a dump that reaches back to the start of the \
         chain, or pass --min-height with the height of the earliest block \
         this archive is expected to hold."
        ~metadata

(** Check that every gap can be closed, without writing anything.  The walk
    cannot advance without ingesting, so this reports the first missing block
    of each branch only. *)
let dry_run (config : Config.t) ~pool ~source ~network ~logger =
  let open Deferred.Or_error.Let_syntax in
  let floor = height_floor config in
  let%bind orphans, _genesis_height = Audit.missing_parents pool in
  let%map () =
    Deferred.Or_error.List.iter ~how:`Sequential orphans ~f:(fun orphan ->
        if Int.( < ) (Audit.Orphan.parent_height orphan) floor then (
          log_below_floor ~logger ~floor ~config orphan ;
          return () )
        else
          let%map (_ : Yojson.Safe.t) =
            fetch_parent config ~source ~network ~logger orphan
          in
          [%log info]
            "Dry run: $block_file is available and decodes as a block. It was \
             not written to the archive."
            ~metadata:
              [ ("block_file", `String (parent_file_name ~network orphan)) ] )
  in
  { blocks_added = 0; branches_left_alone = List.length orphans }

let backfill (config : Config.t) ~pool ~source ~network ~logger
    ~genesis_constants ~constraint_constants ~proof_cache_db =
  let open Deferred.Or_error.Let_syntax in
  let floor = height_floor config in
  let rec go ~added ~skipped ~just_resolved =
    let%bind orphans, _genesis_height = Audit.missing_parents pool in
    (* [just_resolved] names the block whose parent was added on the previous
       iteration.  It must not still be reported as unparented: if it is, the
       ingest reported success without storing the block, and repeating the
       download would loop forever. *)
    let%bind () =
      match just_resolved with
      | Some (state_hash, block_file)
        when List.exists orphans ~f:(fun o ->
                 String.equal o.Audit.Orphan.state_hash state_hash ) ->
          Deferred.return
            (Or_error.errorf
               "no progress: %s was added to the archive but block %s still \
                has no parent. The archive accepted the block without storing \
                it; check the archive logs and the database schema version."
               block_file state_hash )
      | _ ->
          return ()
    in
    let candidates =
      List.filter orphans ~f:(fun o ->
          not (Set.mem skipped o.Audit.Orphan.state_hash) )
    in
    match candidates with
    | [] ->
        return
          { blocks_added = added; branches_left_alone = Set.length skipped }
    | orphan :: _ ->
        if Int.( < ) (Audit.Orphan.parent_height orphan) floor then (
          log_below_floor ~logger ~floor ~config orphan ;
          go ~added
            ~skipped:(Set.add skipped orphan.Audit.Orphan.state_hash)
            ~just_resolved:None )
        else if
          Option.exists config.max_blocks ~f:(fun limit ->
              Int.( >= ) added limit )
        then (
          (* Reaching the limit is what the operator asked for, not a failure:
             report it and stop the pass cleanly, so a daemon does not treat it
             as an error and crash-loop. *)
          [%log info]
            "Stopping after adding $blocks_added blocks, the limit set by \
             --max-blocks. The archive still holds blocks with no parent; run \
             again to continue."
            ~metadata:[ ("blocks_added", `Int added) ] ;
          return
            { blocks_added = added
            ; branches_left_alone = List.length candidates
            } )
        else
          let block_file = parent_file_name ~network orphan in
          let%bind json = fetch_parent config ~source ~network ~logger orphan in
          let%bind () =
            Ingest.add ~format:config.format ~pool ~logger ~genesis_constants
              ~constraint_constants ~proof_cache_db ~json
              ~where:(Block_source.location source ~name:block_file)
          in
          [%log info] "Added block $block_file to the archive"
            ~metadata:
              [ ("block_file", `String block_file)
              ; ("height", `Int (Audit.Orphan.parent_height orphan))
              ; ("state_hash", `String orphan.Audit.Orphan.parent_hash)
              ; ("blocks_added", `Int (added + 1))
              ] ;
          go ~added:(added + 1) ~skipped
            ~just_resolved:(Some (orphan.Audit.Orphan.state_hash, block_file))
  in
  go ~added:0 ~skipped:(Set.empty (module String)) ~just_resolved:None

(** One repair pass: report the state of the archive, fill every gap that can
    be filled, then report the state again. *)
let repair (config : Config.t) ~pool ~logger ~genesis_constants
    ~constraint_constants ~proof_cache_db =
  let source = Option.value_exn config.blocks in
  let network = Option.value_exn config.network in
  let%bind () = describe_state pool ~logger ~when_:"before the repair pass" in
  let%bind result =
    if config.dry_run then dry_run config ~pool ~source ~network ~logger
    else
      backfill config ~pool ~source ~network ~logger ~genesis_constants
        ~constraint_constants ~proof_cache_db
  in
  let%map () = describe_state pool ~logger ~when_:"after the repair pass" in
  result
