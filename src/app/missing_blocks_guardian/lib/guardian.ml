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
   Each of those is a named, terminating outcome here. *)

open Core
open Async

(** A branch the pass could not close, and why.  One unreachable branch must
    not hide the branches that can still be repaired, so the walk sets it
    aside, carries on, and reports it at the end. *)
module Unresolved = struct
  type t = { state_hash : string; height : int; reason : string }

  let to_metadata t =
    [ ("state_hash", `String t.state_hash)
    ; ("height", `Int t.height)
    ; ("reason", `String t.reason)
    ]
end

type outcome = { blocks_added : int; unresolved : Unresolved.t list }

(** A pass is complete when it left no branch unresolved. *)
let is_complete t = List.is_empty t.unresolved

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

let fetch_parent (config : Config.t) ~source ~network ~logger orphan =
  let name = parent_file_name ~network orphan in
  [%log info] "Downloading $block_file"
    ~metadata:
      [ ("block_file", `String name)
      ; ("url", `String (Block_source.location source ~name))
      ] ;
  Block_source.fetch source ~name ~timeout:config.http_timeout
    ~retries:config.retries ~retry_delay:config.retry_delay ~logger

let unresolved_of (orphan : Audit.Orphan.t) ~reason =
  { Unresolved.state_hash = orphan.state_hash; height = orphan.height; reason }

(** Check that every gap can be closed, without writing anything.  The walk
    cannot advance without ingesting, so this reports the first missing block
    of each branch only. *)
let dry_run (config : Config.t) ~pool ~source ~network ~logger =
  let open Deferred.Let_syntax in
  match%bind Audit.missing_parents pool ~min_height:config.min_height with
  | Error err ->
      return (Error err)
  | Ok (orphans, _genesis_height) ->
      let%map unresolved =
        Deferred.List.filter_map ~how:`Sequential orphans ~f:(fun orphan ->
            match%map fetch_parent config ~source ~network ~logger orphan with
            | Ok (_ : Yojson.Safe.t) ->
                [%log info]
                  "Dry run: $block_file is available and decodes as a block. \
                   It was not written to the archive."
                  ~metadata:
                    [ ("block_file", `String (parent_file_name ~network orphan))
                    ] ;
                None
            | Error failure ->
                let reason =
                  Error.to_string_hum (Block_source.error_of_failure failure)
                in
                [%log error]
                  "Dry run: the parent of $state_hash cannot be fetched: \
                   $reason"
                  ~metadata:
                    (Unresolved.to_metadata (unresolved_of orphan ~reason)) ;
                Some (unresolved_of orphan ~reason) )
      in
      Ok { blocks_added = 0; unresolved }

let backfill (config : Config.t) ~pool ~source ~network ~logger
    ~genesis_constants ~constraint_constants ~proof_cache_db =
  let open Deferred.Or_error.Let_syntax in
  let rec go ~added ~unresolved ~just_resolved =
    let%bind orphans, _genesis_height =
      Audit.missing_parents pool ~min_height:config.min_height
    in
    (* [just_resolved] names the block whose parent was added on the previous
       iteration.  It must not still be reported as unparented: if it is, the
       ingest reported success without storing the block, and repeating the
       download would loop forever.  This one is fatal, because it means the
       archive is lying about what it stored. *)
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
    let set_aside = List.map unresolved ~f:(fun u -> u.Unresolved.state_hash) in
    let candidates =
      List.filter orphans ~f:(fun o ->
          not (List.mem set_aside o.Audit.Orphan.state_hash ~equal:String.equal) )
    in
    match candidates with
    | [] ->
        return { blocks_added = added; unresolved = List.rev unresolved }
    | orphan :: _ -> (
        if
          Option.exists config.max_blocks ~f:(fun limit ->
              Int.( >= ) added limit )
        then (
          (* Reaching the limit is what the operator asked for, so the pass
             stops cleanly; the branches still open are reported as
             unresolved, which keeps the exit code honest. *)
          [%log info]
            "Stopping after adding $blocks_added blocks, the limit set by \
             --max-blocks. The archive still holds blocks with no parent; run \
             again to continue."
            ~metadata:[ ("blocks_added", `Int added) ] ;
          let reason = "the --max-blocks limit for this pass was reached" in
          return
            { blocks_added = added
            ; unresolved =
                List.rev unresolved
                @ List.map candidates ~f:(unresolved_of ~reason)
            } )
        else
          let block_file = parent_file_name ~network orphan in
          let set_aside_with reason =
            [%log error] "Leaving the branch under $state_hash open: $reason"
              ~metadata:(Unresolved.to_metadata (unresolved_of orphan ~reason)) ;
            go ~added
              ~unresolved:(unresolved_of orphan ~reason :: unresolved)
              ~just_resolved:None
          in
          let%bind.Deferred fetched =
            fetch_parent config ~source ~network ~logger orphan
          in
          (* A branch whose block cannot be fetched or stored is set aside
             rather than ending the pass: the other branches may still be
             repairable, and the walk goes lowest first, so one truncated
             branch at the bottom would otherwise hide every gap above it. *)
          match fetched with
          | Error failure ->
              set_aside_with
                (Error.to_string_hum (Block_source.error_of_failure failure))
          | Ok json -> (
              let%bind.Deferred ingested =
                Ingest.add ~format:config.format ~pool ~logger
                  ~genesis_constants ~constraint_constants ~proof_cache_db ~json
                  ~where:(Block_source.location source ~name:block_file)
              in
              match ingested with
              | Error err ->
                  set_aside_with (Error.to_string_hum err)
              | Ok () ->
                  [%log info] "Added block $block_file to the archive"
                    ~metadata:
                      [ ("block_file", `String block_file)
                      ; ("height", `Int (Audit.Orphan.parent_height orphan))
                      ; ("state_hash", `String orphan.parent_hash)
                      ; ("blocks_added", `Int (added + 1))
                      ] ;
                  go ~added:(added + 1) ~unresolved
                    ~just_resolved:(Some (orphan.state_hash, block_file)) ) )
  in
  go ~added:0 ~unresolved:[] ~just_resolved:None

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
