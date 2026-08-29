(* audit.ml -- health audit of an archive database.

   This is the check that the standalone [mina-missing-blocks-auditor] used to
   perform.  It is kept as a library module here so that both the [audit]
   subcommand and the backfill loop of [single-run]/[daemon] use exactly one
   implementation and one set of SQL queries. *)

open Core
open Async

(** A block in the archive whose parent is not in the archive. *)
module Orphan = struct
  type t =
    { block_id : int; state_hash : string; height : int; parent_hash : string }

  (** Height of the parent block that has to be fetched to close this gap. *)
  let parent_height t = t.height - 1

  let to_metadata t =
    [ ("block_id", `Int t.block_id)
    ; ("state_hash", `String t.state_hash)
    ; ("height", `Int t.height)
    ; ("parent_hash", `String t.parent_hash)
    ; ("parent_height", `Int (parent_height t))
    ]
end

(* Bits in the exit code.  Bits 0-3 keep the meaning they had in
   [mina-missing-blocks-auditor]; bit 4 is new. *)

let missing_blocks_error = 0

let pending_blocks_error = 1

let chain_length_error = 2

let chain_status_error = 3

(* The archive holds no genesis block and no post-hard-fork first block.  The
   auditor used to die with an opaque Caqti error in this case. *)
let genesis_block_error = 4

module Report = struct
  type t =
    { orphans : (Orphan.t * int option) list
          (** Each orphan, paired with the size of the height gap below it.
              [None] means the archive holds no block below that orphan at
              all, so there is no gap to measure -- the orphan is the bottom
              of the archive. *)
    ; genesis_or_fork_height : int option
    ; highest_canonical : int64 option
    ; pending_below_canonical : int64
    ; canonical_chain_length : int64
    ; invalid_chain_status : (int * string * string) list
    }

  let exit_code t =
    let bits = ref 0 in
    let set n = bits := !bits lor (1 lsl n) in
    if not (List.is_empty t.orphans) then set missing_blocks_error ;
    if Option.is_none t.genesis_or_fork_height then set genesis_block_error ;
    if not (Int64.equal t.pending_below_canonical Int64.zero) then
      set pending_blocks_error ;
    Option.iter t.highest_canonical ~f:(fun highest ->
        if not (Int64.equal t.canonical_chain_length highest) then
          set chain_length_error ) ;
    if not (List.is_empty t.invalid_chain_status) then set chain_status_error ;
    !bits

  let is_healthy t = Int.equal (exit_code t) 0
end

(* Run one query against the pool, turning a Caqti error into an [Error.t] that
   names the query.  The old auditor logged [Caqti_error.show] and then called
   [exit 1] from deep inside the query helper, which made every failure look
   the same to the caller. *)
let query pool ~what f =
  match%map Mina_caqti.Pool.use f pool with
  | Ok x ->
      Ok x
  | Error err ->
      Or_error.errorf "%s failed: %s" what (Caqti_error.show err)

let genesis_or_fork_height pool =
  query pool ~what:"querying the genesis or first hard-fork block height"
    (fun db -> Sql.GenesisOrFirstForkBlockHeight.run db () )

(** Blocks whose parent is absent from the archive, excluding the genesis or
    first post-hard-fork block, which has no parent by construction.  This is
    the cheap query the backfill loop repeats after every ingested block; it
    deliberately avoids the recursive canonical-chain query of a full
    {!report}. *)
let missing_parents pool =
  let open Deferred.Or_error.Let_syntax in
  let%bind raw =
    query pool ~what:"querying blocks with no parent" (fun db ->
        Sql.Unparented_blocks_detail.run db () )
  in
  let%map genesis_height = genesis_or_fork_height pool in
  let orphans =
    List.filter_map raw ~f:(fun (block_id, state_hash, height, parent_hash) ->
        if Option.exists genesis_height ~f:(Int.equal height) then None
        else Some { Orphan.block_id; state_hash; height; parent_hash } )
    |> List.sort ~compare:(fun a b -> Int.compare a.Orphan.height b.height)
  in
  (orphans, genesis_height)

(** Read enough of the archive to prove the connection works and the schema is
    the one we expect, before any block is downloaded. *)
let preflight pool =
  query pool ~what:"counting blocks in the archive" (fun db ->
      Sql.Block_count.run db () )

let report pool =
  let open Deferred.Or_error.Let_syntax in
  let%bind orphans, genesis_or_fork_height = missing_parents pool in
  let%bind orphans =
    Deferred.Or_error.List.map ~how:`Sequential orphans ~f:(fun orphan ->
        let%map gap =
          query pool ~what:"querying the size of a missing block gap" (fun db ->
              Sql.Missing_blocks_gap.run db orphan.Orphan.height )
        in
        (orphan, gap) )
  in
  let%bind highest_canonical =
    query pool ~what:"querying the greatest height of canonical blocks"
      (fun db -> Sql.Chain_status.run_highest_canonical db () )
  in
  match highest_canonical with
  | None ->
      (* No canonical block at all.  There is no chain to walk, so the
         chain-length and chain-status checks have nothing to say; the missing
         genesis bit and the orphan list carry the diagnosis. *)
      return
        { Report.orphans
        ; genesis_or_fork_height
        ; highest_canonical = None
        ; pending_below_canonical = Int64.zero
        ; canonical_chain_length = Int64.zero
        ; invalid_chain_status = []
        }
  | Some highest_canonical ->
      let%bind pending_below_canonical =
        query pool
          ~what:
            "querying the number of pending blocks below the highest canonical \
             block" (fun db ->
            Sql.Chain_status.run_count_pending_below db highest_canonical )
      in
      let%map canonical_chain =
        query pool ~what:"querying the canonical chain" (fun db ->
            Sql.Chain_status.run_canonical_chain db highest_canonical )
      in
      let invalid_chain_status =
        List.filter canonical_chain ~f:(fun (_block_id, _state_hash, status) ->
            not (String.equal status "canonical") )
      in
      { Report.orphans
      ; genesis_or_fork_height
      ; highest_canonical = Some highest_canonical
      ; pending_below_canonical
      ; canonical_chain_length = List.length canonical_chain |> Int64.of_int
      ; invalid_chain_status
      }

(* The messages below are the ones [mina-missing-blocks-auditor] emitted, kept
   verbatim so that log-scraping alerts keep matching. *)
let log_report ~logger (t : Report.t) =
  ( match t.genesis_or_fork_height with
  | Some _ ->
      ()
  | None ->
      [%log error]
        "The archive holds no genesis block and no first post-hard-fork block. \
         Every block below the earliest stored block will be reported as \
         missing, and the guardian cannot tell where the chain is supposed to \
         start. Restore a dump that reaches back to the start of the chain, or \
         pass --min-height with the height of the earliest block this archive \
         is expected to hold." ) ;
  if List.is_empty t.orphans then
    [%log info] "There are no missing blocks in the archive db"
  else
    List.iter t.orphans ~f:(fun (orphan, gap) ->
        let gap_metadata =
          match gap with
          | Some gap ->
              [ ("missing_blocks_gap", `Int gap) ]
          | None ->
              (* Nothing at all below this block, so the gap has no size. *)
              [ ("missing_blocks_gap", `Null)
              ; ("lowest_block_in_archive", `Bool true)
              ]
        in
        [%log info] "Block has no parent in archive db"
          ~metadata:(Orphan.to_metadata orphan @ gap_metadata) ) ;
  [%log info] "Querying for gaps in chain statuses" ;
  match t.highest_canonical with
  | None ->
      [%log error]
        "There are no canonical blocks in the archive db, so the chain status \
         and chain length checks were skipped"
  | Some highest_canonical ->
      if Int64.equal t.pending_below_canonical Int64.zero then
        [%log info] "There are no gaps in the chain statuses"
      else
        [%log info]
          "There are $num_pending_blocks_below pending blocks lower than the \
           highest canonical block"
          ~metadata:
            [ ( "max_height_canonical_block"
              , `String (Int64.to_string highest_canonical) )
            ; ( "num_pending_blocks_below"
              , `String (Int64.to_string t.pending_below_canonical) )
            ] ;
      ( if Int64.equal t.canonical_chain_length highest_canonical then
          [%log info] "Length of canonical chain is %Ld blocks"
            t.canonical_chain_length
        else
          match t.genesis_or_fork_height with
          | Some 1 | None ->
              [%log info]
                "Length of canonical chain is %Ld blocks, expected: %Ld"
                t.canonical_chain_length highest_canonical
          | Some genesis_or_fork_height ->
              [%log info]
                "Length of canonical chain is %Ld blocks, expected: %Ld. \
                 (Note: genesis or first fork block has height %d)"
                t.canonical_chain_length highest_canonical
                genesis_or_fork_height ) ;
      if List.is_empty t.invalid_chain_status then
        [%log info]
          "All blocks along the canonical chain have a valid chain status"
      else
        List.iter t.invalid_chain_status
          ~f:(fun (block_id, state_hash, chain_status) ->
            [%log info]
              "Canonical block has a chain_status other than \"canonical\""
              ~metadata:
                [ ("block_id", `Int block_id)
                ; ("state_hash", `String state_hash)
                ; ("chain_status", `String chain_status)
                ] )
