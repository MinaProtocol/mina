(* guardian.ml -- walk back from every block whose parent is missing and fill
   the gap from the block source. Which blocks lack a parent is the missing
   blocks auditor's [Audit.missing_parents].

   Every way the walk can fail to make progress -- a block the source does
   not hold, an ingest that stores nothing, a chain that runs down to height 1
   or [--min-height] without reaching a genesis or fork block -- is a named,
   terminating outcome. *)

open Core
open Async
module Audit = Missing_blocks_auditor_lib.Audit

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

(** The archive the blocks are written to. *)
type archive =
  { pool : (Caqti_async.connection, Caqti_error.t) Mina_caqti.Pool.t
  ; genesis_constants : Genesis_constants.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  ; proof_cache_db : Proof_cache_tag.cache_db
  }

let unresolved_of (orphan : Audit.Orphan.t) ~reason =
  { Unresolved.state_hash = orphan.state_hash; height = orphan.height; reason }

(** Download the parent of [orphan]: the block that closes its gap. *)
let fetch_parent (config : Config.t) source ~logger (orphan : Audit.Orphan.t) =
  let name =
    Block_source.file_name source
      ~height:(Audit.Orphan.parent_height orphan)
      ~state_hash:orphan.parent_hash
  in
  [%log info] "Downloading $block_file"
    ~metadata:
      [ ("block_file", `String name)
      ; ("url", `String (Block_source.location source ~name))
      ] ;
  let%map fetched =
    Block_source.fetch source ~name ~timeout:config.http_timeout
      ~retries:config.retries ~retry_delay:config.retry_delay ~logger
  in
  Or_error.map fetched ~f:(fun json -> (name, json))

let add_block (config : Config.t) archive ~logger ~where json =
  match%map
    Archive_lib.Block_json.add ~format:config.format
      ~proof_cache_db:archive.proof_cache_db
      ~genesis_constants:archive.genesis_constants
      ~constraint_constants:archive.constraint_constants ~pool:archive.pool
      ~logger json
  with
  | Ok () ->
      Ok ()
  | Error (Decode reason) ->
      Or_error.errorf "%s does not decode as a %s block: %s" where
        (Archive_lib.Block_json.format_to_string config.format)
        reason
  | Error (Rejected err) ->
      Or_error.errorf "the archive rejected the block from %s: %s" where
        (Caqti_error.show err)

(** Fetch and add the parent of [orphan]; the block file name, or why not. *)
let close_gap config archive source ~logger orphan =
  let open Deferred.Or_error.Let_syntax in
  let%bind name, json = fetch_parent config source ~logger orphan in
  let%map () =
    add_block config archive ~logger
      ~where:(Block_source.location source ~name)
      json
  in
  name

(** A block whose parent was added on the previous step must not still lack
    one: if it does, the archive accepted the block without storing it, and
    fetching it again would loop forever. *)
let check_progress orphans ~just_added =
  match just_added with
  | Some (state_hash, block_file)
    when List.exists orphans ~f:(fun (o : Audit.Orphan.t) ->
             String.equal o.state_hash state_hash ) ->
      Or_error.errorf
        "no progress: %s was added to the archive but block %s still has no \
         parent. The archive accepted the block without storing it; check the \
         archive logs and the database schema version."
        block_file state_hash
  | _ ->
      Ok ()

(** The branches not yet set aside. *)
let still_open orphans ~unresolved =
  List.filter orphans ~f:(fun (o : Audit.Orphan.t) ->
      not
        (List.exists unresolved ~f:(fun (u : Unresolved.t) ->
             String.equal u.state_hash o.state_hash ) ) )

let limit_reached (config : Config.t) ~added =
  Option.exists config.max_blocks ~f:(fun limit -> Int.( >= ) added limit)

(** Check that every gap can be closed, without writing anything. The walk
    cannot advance without adding blocks, so only the first missing block of
    each branch is checked. *)
let dry_run (config : Config.t) archive source ~logger =
  let open Deferred.Or_error.Let_syntax in
  let%bind orphans, _ =
    Audit.missing_parents archive.pool ~min_height:config.min_height
  in
  let%map.Deferred unresolved =
    Deferred.List.filter_map ~how:`Sequential orphans ~f:(fun orphan ->
        match%map.Deferred fetch_parent config source ~logger orphan with
        | Ok (name, (_ : Yojson.Safe.t)) ->
            [%log info]
              "Dry run: $block_file is available and decodes as a block. It \
               was not written to the archive."
              ~metadata:[ ("block_file", `String name) ] ;
            None
        | Error failure ->
            let unresolved =
              unresolved_of orphan ~reason:(Error.to_string_hum failure)
            in
            [%log error]
              "Dry run: the parent of $state_hash cannot be fetched: $reason"
              ~metadata:(Unresolved.to_metadata unresolved) ;
            Some unresolved )
  in
  Ok { blocks_added = 0; unresolved }

(** Close every gap, lowest first. A branch that cannot be closed is set aside
    and reported, so one unreachable block at the bottom does not hide the
    gaps above it. *)
let backfill (config : Config.t) archive source ~logger =
  let open Deferred.Or_error.Let_syntax in
  let rec step ~added ~unresolved ~just_added =
    let%bind orphans, _ =
      Audit.missing_parents archive.pool ~min_height:config.min_height
    in
    let%bind () = Deferred.return (check_progress orphans ~just_added) in
    match still_open orphans ~unresolved with
    | [] ->
        return { blocks_added = added; unresolved = List.rev unresolved }
    | open_branches when limit_reached config ~added ->
        [%log info]
          "Stopping after adding $blocks_added blocks, the limit set by \
           --max-blocks. Run again to continue."
          ~metadata:[ ("blocks_added", `Int added) ] ;
        let reason = "the --max-blocks limit for this pass was reached" in
        return
          { blocks_added = added
          ; unresolved =
              List.rev unresolved
              @ List.map open_branches ~f:(unresolved_of ~reason)
          }
    | orphan :: _ -> (
        match%bind.Deferred close_gap config archive source ~logger orphan with
        | Ok block_file ->
            [%log info] "Added block $block_file to the archive"
              ~metadata:
                [ ("block_file", `String block_file)
                ; ("height", `Int (Audit.Orphan.parent_height orphan))
                ; ("state_hash", `String orphan.parent_hash)
                ; ("blocks_added", `Int (added + 1))
                ] ;
            step ~added:(added + 1) ~unresolved
              ~just_added:(Some (orphan.state_hash, block_file))
        | Error failure ->
            let set_aside =
              unresolved_of orphan ~reason:(Error.to_string_hum failure)
            in
            [%log error] "Leaving the branch under $state_hash open: $reason"
              ~metadata:(Unresolved.to_metadata set_aside) ;
            step ~added ~unresolved:(set_aside :: unresolved) ~just_added:None )
  in
  step ~added:0 ~unresolved:[] ~just_added:None

(** One repair pass: report the state of the archive, fill every gap that can
    be filled, then report the state again. *)
let repair (config : Config.t) archive ~logger =
  let source = Option.value_exn config.blocks in
  let%bind () =
    describe_state archive.pool ~logger ~when_:"before the repair pass"
  in
  let%bind result =
    if config.dry_run then dry_run config archive source ~logger
    else backfill config archive source ~logger
  in
  let%map () =
    describe_state archive.pool ~logger ~when_:"after the repair pass"
  in
  result
